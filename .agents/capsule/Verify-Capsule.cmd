@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Verify-Capsule.ps1" -CapsuleRoot "%~dp0.."
