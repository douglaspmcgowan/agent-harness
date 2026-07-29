@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bootstrap-Capsule.ps1" -CapsuleRoot "%~dp0.."
