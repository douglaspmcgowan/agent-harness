@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Initialize-AgentProject.ps1" %*
