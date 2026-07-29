---
name: project-openclaw-lab-workstation
description: "Doug uses OpenClaw (agentic framework) and is spec'ing a sub-$5K UC lab workstation for COMSOL/ANSYS + local LLM fine-tuning + many OpenClaw instances"
metadata:
  node_type: memory
  type: project
  originSessionId: 0a6f77f0-6d2e-492b-a0ce-4bed13265ce2
---

**Doug uses OpenClaw** — a self-hosted, model-agnostic agentic framework (always-on agents: Gateway/Brain/Memory/Skills/Heartbeat; drives cloud models OR local models via Ollama/vLLM). He runs "a bunch of" concurrent instances. NOTE: OpenClaw post-dates the May-2025 training cutoff — when Doug says "open claw"/"openclaw" he means **OpenClaw, NOT Claude Code**. (I got this wrong once; he corrected me.)

As of 2026-06-02 he's spec'ing a **single workstation, hard budget under $5,000, purchased via UC Berkeley grant/BearBuy**, to run three workloads at once: COMSOL/ANSYS physics sims, local LLM inference + LoRA fine-tuning, and many OpenClaw instances.

Recommendation that the research landed on:

- **Anchor GPU: NVIDIA RTX 4500 Ada (24GB ECC, ~$2,250)** — best VRAM/$ that's procurement-legal and fits an OEM tower. 24GB is the ceiling at $5K.
- **Machine: Dell Precision 3680** (i9-14900, 64GB, add 2TB NVMe) via BearBuy ~$4.4–4.9K. Alts: Lenovo ThinkStation P3 Tower Gen 2 (cheaper), or a Bizon/Puget custom quote.
- **Architecture: run OpenClaw agents on CLOUD models** to free the local GPU for fine-tuning + COMSOL GPU accel; use **vLLM not Ollama** if running local models; **overflow big FEA to the Savio HPC cluster**.

**Why:** budget hard-capped; VRAM is the bottleneck all three workloads fight over, so the design decouples agents (→cloud) and big sims (→cluster) from the local box.

**Open items Doug must confirm before buying:** (1) **ANSYS HPC Pack license** — Mechanical caps at 4 cores without it, so a high-core CPU would be wasted; (2) lab **COMSOL license + whether Savio** can host ANSYS/COMSOL (not in Savio's default modules today).

**How to apply:** This is the live hardware decision. Prices/SKUs are volatile — reverify before he acts. Procurement path details in [[reference-uc-berkeley-procurement]].
