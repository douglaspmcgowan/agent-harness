@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restore-AgentWorkspace.ps1" %*
