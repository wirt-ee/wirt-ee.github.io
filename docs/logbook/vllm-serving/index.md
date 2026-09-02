---
date: 2026-08-29
tags: [ai, vllm, gpu, systemd]
description: "On-prem LLM serving with vLLM: GLM-5.2/5.3 NVFP4 on an 8-GPU node, gemma-4-26B FP8 on a single L40S, MTP speculative decoding, and the production systemd shape."
---

# vLLM serving, production shape

Context: on-prem LLM inference — the kind where the data cannot leave. Two serving profiles: an 8-GPU node running GLM-5.2/5.3 (NVFP4 MoE, expert parallel, 256K context), and a single L40S running gemma-4-26B FP8. Ubuntu 24.04, vLLM in a uv-managed venv, systemd on top. The front door in front of these engines — keys, routing, TLS — is the [LiteLLM proxy entry](../litellm-proxy/index.md). Hostnames genericized; the API key below is a placeholder.

## Install

    curl -LsSf https://astral.sh/uv/install.sh | sh
    source $HOME/.local/bin/env
    uv venv --python 3.12 --seed
    source .venv/bin/activate
    uv pip install vllm --torch-backend=auto

The unglamorous apt layer underneath: `ffmpeg` (torchcodec wants it), `numactl` (NUMA binding), `build-essential` + `python3.12-dev` (Triton compiles), `ninja-build`.

## Models

    pip install -U huggingface_hub
    hf download nvidia/GLM-5.2-NVFP4 --local-dir /models/GLM-5.2-NVFP4
    hf download google/gemma-4-26B-A4B-it --local-dir /models/gemma-4-26B-A4B-it
    hf download google/gemma-4-26B-A4B-it-assistant ...   # MTP draft model
    hf download Qwen/Qwen2.5-VL-72B-Instruct-AWQ ...      # vision

## What bit

1. **`trtllm_batch_decode_with_kv_cache_mla() got an unexpected keyword argument 'kv_scale_format'`** — the pinned FlashInfer is older than the vLLM calling it. Upgrade FlashInfer and tell vLLM to stop checking versions:

        pip install -U flashinfer-python flashinfer-cubin
        export FLASHINFER_DISABLE_VERSION_CHECK=1

2. **`Half finished FlashInferMLASparseSM120Impl`** — a literally half-finished backend class for the SM120 GPU. Patch it: back up the file, apply the patch script, restart vLLM.

3. **The CUDA graph memory hint nobody reads.** At `--gpu-memory-utilization 0.95`, vLLM logs that with CUDA graph memory profiling this is *effectively* 0.9124 — and suggests 0.9876 for the same usable KV cache. Tempting; 0.98 OOMs at 256K context on this hardware. 0.95 with `--max-model-len 256K` is the stable point.

4. **Model upgrades pull vLLM upgrades.** GLM-5.3-NVFP4 needed vLLM 0.28.0; the node ran 0.25.0. Back up the whole venv first (`cp -a .venv .venv-vllm025-backup`), then:

        pip install -U "vllm>=0.28.0" --extra-index-url https://flashinfer.ai/whl
        pip install -U flashinfer-cubin==0.6.16.post3 --extra-index-url https://flashinfer.ai/whl

5. **MTP on gemma needed a patch** to `vllm/v1/spec_decode/llm_base_proposer.py` — the draft model's embedding path. Patch script writes its own `.bak`; restart vLLM after.

## The serving commands

8-GPU node, the final stable shape:

    vllm serve /models/GLM-5.2-NVFP4 --served-model-name glm-5.2 \
      --tensor-parallel-size 8 --enable-expert-parallel \
      --disable-custom-all-reduce --numa-bind --performance-mode interactivity \
      --trust-remote-code --kv-cache-dtype fp8_e4m3 \
      --gpu-memory-utilization 0.95 --max-model-len 256K \
      --host <ip> --port 8000

Single L40S, FP8, with MTP speculative decoding from the draft model:

    vllm serve /models/gemma-4-26B-A4B-it --quantization fp8 \
      --served-model-name gemma-4-26b-a4b --tensor-parallel-size 1 \
      --gpu-memory-utilization 0.93 --kv-cache-dtype fp8 --max-model-len 32768 \
      --max-num-seqs 64 --enable-prefix-caching \
      --cudagraph-capture-sizes 1 2 4 8 16 --async-scheduling \
      --enable-auto-tool-choice --tool-call-parser gemma4 --reasoning-parser gemma4 \
      --speculative-config '{"method":"mtp","model":"/models/gemma-4-26B-A4B-it-assistant","num_speculative_tokens":4}' \
      --trust-remote-code --host <ip> --port 8000

## Production shape

Cache directories *before* the first start — vLLM, Triton, torchinductor, CUDA and huggingface each want one:

    mkdir /models /var/cache/huggingface /var/cache/vllm /var/cache/triton \
          /var/cache/torchinductor /var/cache/nv

Environment in `/etc/vllm/vllm.env` (`chmod 400`), the essentials:

    VLLM_API_KEY=<key>
    HF_HOME=/var/cache/huggingface
    VLLM_CACHE_ROOT=/var/cache/vllm
    TRITON_CACHE_DIR=/var/cache/triton
    TORCHINDUCTOR_CACHE_DIR=/var/cache/torchinductor
    CUDA_MODULE_LOADING=LAZY
    CUDA_DEVICE_ORDER=PCI_BUS_ID
    NCCL_CUMEM_ENABLE=1
    PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
    FLASHINFER_DISABLE_VERSION_CHECK=1
    HF_HUB_OFFLINE=1        # model is on disk; do not phone home

The systemd unit earns its keep on the restart and shutdown behavior — a 400K-context model takes minutes to load and seconds to corrupt if killed wrong:

    [Service]
    Type=simple
    EnvironmentFile=/etc/vllm/vllm.env
    ExecStart=/root/.venv/bin/vllm serve ...
    Restart=on-failure
    RestartSec=10
    TimeoutStartSec=900
    TimeoutStopSec=120
    KillSignal=SIGINT
    KillMode=mixed
    LimitNOFILE=1048576
    OOMScoreAdjust=-900

Front it with nftables — default drop input, allow established, loopback, ICMP both families, SSH, and the API ports only:

    table inet filter {
        chain input {
            type filter hook input priority filter; policy drop;
            ct state established,related accept
            ct state invalid drop
            iif lo accept
            ip protocol icmp accept
            ip6 nexthdr icmpv6 accept
            tcp dport 22 accept
            tcp dport 8000-8001 accept
        }
    }

For benchmarking, ShareGPT (Vicuna unfiltered split) through the OpenAI-compatible API with a small concurrency harness — numbers before and after every flag change, or the flag changes are just feelings.

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
