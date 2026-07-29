@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enable-Gitleaks.ps1" %*
