---
date: 2026-07-17
tags: [ai, litellm, nginx, systemd]
description: "LiteLLM proxy in front of the vLLM backends: virtual keys, health-check routing, a hardened systemd unit, and the nginx config that makes SSE streaming survive."
---

# LiteLLM in front of vLLM

Context: the [vLLM serving](../vllm-serving/index.md) entry covers the engines. This is the front door — a LiteLLM proxy in front of them: one OpenAI-compatible endpoint, virtual keys per consumer, spend tracking, health-check routing between duplicated backends. PostgreSQL for the UI, nginx for TLS, systemd for the process. The date is the certificate issuance; the stack was built over the weeks around it.

## Install and the prisma wart

    uv tool install prisma
    uv tool install 'litellm[proxy]'

LiteLLM shells out to `prisma` at startup (`migrate deploy`), and the bundled schema generation is broken out of the box — generate it explicitly against the installed package:

    LITELLM=~/.local/share/uv/tools/litellm
    PATH="$LITELLM/bin:$PATH" "$LITELLM/bin/python" -m prisma generate \
        --schema="$LITELLM/lib/python3.12/site-packages/litellm_proxy_extras/schema.prisma"

## Database and environment

    sudo -u postgres psql
    postgres=# CREATE USER litellm WITH PASSWORD '<secret>';
    postgres=# CREATE DATABASE litellm OWNER litellm;

    # ~/.config/litellm/litellm.env
    export LITELLM_MASTER_KEY=sk-<key>
    export LITELLM_PORT=443
    export DATABASE_URL="postgresql://litellm:<user>@<host>:5432/litellm"

The master key never appears in the config file; virtual keys for consumers are minted from the UI.

## config.yml — routing that fails over

Two entries with the same `model_name` are two backends behind one name — the router shuffles, health-checks, and cools down:

    model_list:
      - model_name: glm-5.2
        litellm_params:
          model: openai/glm-5.2
          api_base: http://<backend-1>:8000/v1
          api_key: <secret>
          stream_timeout: 900
        model_info:
          health_check_timeout: 5
          input_cost_per_token: 0.00000035
          output_cost_per_token: 0.00000175
      - model_name: glm-5.2          # same name, second backend
        ...

    general_settings:
      background_health_checks: true
      health_check_interval: 30
      enable_health_check_routing: true
      health_check_ignore_transient_errors: true

    router_settings:
      routing_strategy: simple-shuffle
      enable_weighted_failover: true
      num_retries: 2
      retry_after: 1
      timeout: 5
      cooldown_time: 60
      allowed_fails_policy:
        AuthenticationErrorAllowedFails: 0
        TimeoutErrorAllowedFails: 2
        RateLimitErrorAllowedFails: 5

The `allowed_fails_policy` is the part worth staring at: auth errors never fail over (a bad key is a bad key everywhere), timeouts twice, rate limits five times.

## The systemd unit

Beyond the usual: the PATH must include the uv tools (prisma lives in `~/.local/bin`), and the first boot runs prisma migrations, so give it room:

    [Unit]
    After=network-online.target postgresql.service
    StartLimitIntervalSec=60
    StartLimitBurst=5

    [Service]
    User=litellm
    EnvironmentFile=/home/litellm/.config/litellm/litellm.env
    Environment="PATH=/home/litellm/.local/bin:/usr/local/bin:/usr/bin:/bin"
    ExecStart=/home/litellm/.local/bin/litellm --config /home/litellm/.config/litellm/config.yml
    NoNewPrivileges=true
    ProtectSystem=strict
    ReadWritePaths=/home/litellm
    PrivateTmp=true
    RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
    LockPersonality=true
    RestrictSUIDSGID=true
    CapabilityBoundingSet=
    Restart=on-failure
    RestartSec=5s
    TimeoutStartSec=180           # prisma migrate deploy + engine spin-up

## nginx: making SSE survive

The hard-won part. An LLM proxy that breaks streaming is worse than no proxy — a healthy stream that stalls looks dead. Six rules, each earned:

1. **HTTP/1.1 to the upstream, `Connection ""` cleared** — or nginx speaks HTTP/1.0, chunked encoding breaks, SSE stalls.
2. **`proxy_buffering off`** — buffered SSE is batches-then-bursts; looks dead, isn't.
3. **`gzip off` on the streaming path** — gzip buffers the whole response.
4. **nginx timeouts *higher* than litellm's `stream_timeout`** — litellm must be the one that gives up, so its fallback and retry logic runs. nginx cutting first is a 504 with no recovery.
5. **`proxy_next_upstream off`** — litellm is the single retry authority; nginx retrying too duplicates calls and corrupts accounting.
6. **`lingering_close always`** — clean SSE teardown for slow client readers.

    location /v1 {
        proxy_pass http://litellm_backend;
        proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_buffering         off;
        proxy_request_buffering off;
        proxy_cache             off;
        gzip off;
        proxy_connect_timeout 60s;
        proxy_send_timeout    1800s;
        proxy_read_timeout    1800s;
        proxy_next_upstream     off;
        proxy_intercept_errors  off;
        send_timeout            1800s;
        reset_timedout_connection on;
        lingering_close    always;
        lingering_timeout  30s;
    }

## Hiding the internals

LiteLLM answers with a stack of `x-litellm-*` headers — and `x-litellm-model-api-base` **leaks the backend IP on every response** (set in `common_request_processing.py`). Strip them all at the server level; `proxy_hide_header` inherits into locations that define none of their own:

    proxy_hide_header x-litellm-model-api-base;
    proxy_hide_header x-litellm-model-id;
    proxy_hide_header x-litellm-model-name;
    proxy_hide_header x-litellm-response-cost;
    proxy_hide_header x-litellm-key-spend;
    proxy_hide_header x-litellm-key-max-budget;
    # ... the rest of the x-litellm-* family

The unauthenticated discovery surface goes away entirely — `/openapi.json` alone is ~1.2 MB and enumerates all 504 endpoints (admin, billing, key-management):

    location = /openapi.json { return 404; }
    location ^~ /swagger     { return 404; }
    location = /redoc        { return 404; }
    location ^~ /docs        { return 404; }
    location = /             { return 404; }   # root would otherwise load Swagger UI

And `/health/readiness` answers `{"db":"connected"}` to anyone — restrict it to loopback; external uptime checks use `/health/liveliness`.

## TLS

certbot with the webroot method against the nginx vhost (port 80 serves `/.well-known/acme-challenge/` and redirects everything else). One detail that cost an evening: the first DNS zone tried had propagation problems — if ACME validation mysteriously fails, suspect DNS before nginx. Renewal hook, because litellm holds the port:

    # /etc/letsencrypt/renewal-hooks/deploy/restart-litellm.sh
    #!/bin/sh
    case " $RENEWED_DOMAINS " in *" <your-domain> "*) ;; *) exit 0;; esac
    systemctl restart litellm 2>/dev/null || true

---

*This saved you a night? I do this for a living: [info@wirt.ee](mailto:info@wirt.ee).*
