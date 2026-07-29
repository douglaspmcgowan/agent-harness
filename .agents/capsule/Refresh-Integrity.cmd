@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Refresh-Integrity.ps1" -CapsuleRoot "%~dp0.."
