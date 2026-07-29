---
name: BSOD diagnosis history
description: Ongoing diagnosis of recurring 0x7E BSODs on ThinkPad P16 - nvlddmkm.sys crash during Modern Standby, WHEA PCIe errors from NVIDIA GPU
type: project
---

Four confirmed BSODs, all identical signature and same failure hash {7eea5677-f68d-2154-717e-887e07e55cd3}:
- Bugcheck 0x7E (SYSTEM_THREAD_EXCEPTION_NOT_HANDLED)
- Exception 0xC0000005 (access violation) in nvlddmkm.sys
- All crashes during Modern Standby (S0 low power idle) — ConnectedStandbyInProgress: true in every Event ID 41

Crash dump details:
1. Mar 5 (nvlddmkm+0x645ed) — read from 0x0 (null pointer)
2. Mar 16 (nvlddmkm+0x645ed) — read from 0x0 (null pointer), same offset as #1
3. Mar 31 (nvlddmkm+0x5d34d) — read from 0xFFFFFFFFFFFFFFFF, rax contained x86 opcode bytes (memory corruption on PCIe bus)
4. Apr 1 (nvlddmkm+0x5d33a) — read from 0x30 (null struct pointer + offset), 3.5hrs after crash #3

Other recurring events at every boot:
- WHEA Event ID 17 PCIe AER errors from NVIDIA GPU (Bus 0x1, VEN_10DE&DEV_24BA), UncorrectableErrorStatus 0x100000, CorrectableErrorStatus 0xa000
- Intel Wi-Fi 6E AX211 (Netwtw14) Event ID 7003/7021/6062 warnings during standby transitions
- Firmware throttling (Event ID 37) on all 24 processor cores
- Intel Platform License Manager Service timeout (Event ID 7009)
- WUDFRd driver load failures during early boot (benign — retries after SCM starts)
- DCOM 10016 warnings for Windows Security Center components (cosmetic/benign)
- Energy Server Service queencreek unexpected termination (Intel power management)

**Root cause:** GPU drops off PCIe bus during Modern Standby power transitions. Wi-Fi driver cycling (scanning for networks while lid closed during commute) triggers PCIe bus activity that wakes GPU; GPU fails the D3→D0 power transition; nvlddmkm.sys reads corrupted/null pointer; OS crashes.

**Hardware assessment:** WHEA PCIe errors appear at every boot but may be normal for NVIDIA laptop GPU initialization (corrected errors). GPU works fine under normal active use. Problem is specifically the sleep/wake power management — points more toward firmware/driver limitation than dying hardware. No BIOS update available beyond 1.69. Lenovo warranty service is an option if workaround is insufficient.

Crash trigger pattern: close lid on campus Wi-Fi (eduroam/UC Berkeley guest), commute home, open at home Wi-Fi ("Berkeley 1636"). Crash happens mid-commute during Modern Standby — Wi-Fi driver cycling through networks causes PCIe bus activity that wakes GPU, GPU fails power transition. One crash showed 26 standby wake cycles during a single commute.

Actions taken (as of ~2026-03-16):
1. DDU clean uninstall in Safe Mode
2. Lenovo-certified NVIDIA driver installed (ThinkPad Video Features, ~920MB)
3. NVIDIA App removed, NVIDIA Control Panel retained
4. Windows Update blocked from auto-installing drivers (Group Policy + Device Installation Settings)
5. Lenovo Vantage set as trusted update path

Actions taken (as of 2026-04-01):
6. Crashes continued after clean driver install (Mar 31 + Apr 1) — confirmed hardware-level
7. PlatformAoAcOverride=0 set to disable Modern Standby
8. ThinkPad P16 Gen 1 firmware does NOT support S3 — only Hibernate available after disabling S0
9. Lid close action set to Hibernate (powercfg LIDACTION 2)
10. No BIOS update available beyond current 1.69 — only monitor INF file offered
11. WHEA PCIe AER errors (Event ID 17) from NVIDIA GPU appear at every single boot

Pending:
- Verify hibernate eliminates the crash-on-commute scenario
- Intel Wi-Fi driver update not yet done
- If crashes persist even with hibernate, hardware service needed
