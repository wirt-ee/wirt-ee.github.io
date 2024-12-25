---
title: Varia
---
##Company logo
Since entropy tends to increase when left unchecked, our company logo is an OpenSCAD [code](assets/wirt_logo.scad). Any ambiguities are potential sources of anticipation. Visual representation hints that we must view in all directions to keep systems afloat.

##Verify SHA-256 checksum
To put an almost successful scam story short. Do not trust what you [see](assets/tampered.png)! It may be a "legitimate" document from known sources.
For the bare minimum, ask for data integrity verifications using the SHA-256 (SHA-2 family with a digest length of 256 bits).
Data providers can so easily generate and publish hashes without even thinking about GDPR. Let's step through a simple example.

First, generate some files with different content:
```
$ for i in {2345..2348};do date +"%T.%6N" >  bill_${i}.pdf;done 
```

Then shasum everithing:
```
$ sha256sum *
c46dd8a87ecabd1e2003d08bb7e0e8702e18767d6b126f4f00ff79b95cc73276  bill_2345.pdf
a1f0219644c86e4490a0a87b86a1717322dfb67c8148cc5205ca4ce8ac64b54e  bill_2346.pdf
3e8d7257bfa1ed995e2ceaf61404b7ab83ac978f62d0a8f09cb2e1b8ed35c181  bill_2347.pdf
6e1f15409e50c5c1253197971a1f04c01fe456a284f6d6c9e4f4a98e5044e2d7  bill_2348.pdf
```

And then let's generate the publically shareable file ( via the company webpage):
```
sha256sum * > january_bills.txt
```

Now, we can distribute those files via a not-so-secure channel. And if the user wants to check file authenticity, it's easily doable:
```
$ sha256sum bill_2345.pdf
c46dd8a87ecabd1e2003d08bb7e0e8702e18767d6b126f4f00ff79b95cc73276  bill_2345.pdf
```

If the file is tampered, then result is NOT what you published on your company webpage:
```
$ echo "tampering" >>  bill_2345.pdf
$ sha256sum bill_2345.pdf
867b5be7d12023f2268f5c9124eb5a518852195019fd3f067322963724b1d5be  bill_2345.pdf
```

