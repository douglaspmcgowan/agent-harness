@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Ensure-AgentProject.ps1" %*
