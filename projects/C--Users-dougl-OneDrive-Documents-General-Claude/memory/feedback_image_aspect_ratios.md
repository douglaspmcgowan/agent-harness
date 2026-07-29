---
name: Image aspect ratio preservation
description: When resizing images, always preserve original aspect ratio unless explicitly told otherwise
type: feedback
originSessionId: 19da6ad4-51e0-4c9c-8477-3e66eacc6741
---
When resizing or embedding images, always preserve the original aspect ratio. Never stretch or distort.

**Why:** Distorted images look broken and unprofessional, especially in research/portfolio sites.

**How to apply:** Use `object-fit: contain` or `object-fit: cover` in CSS. In code, calculate height from width × (original_h/original_w). Flag if the target dimensions would require cropping.
