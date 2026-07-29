@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Get-EnvironmentVariableMetadata.ps1" %*
