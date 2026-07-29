@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Set-CapsuleAccounts.ps1" -CapsuleRoot "%~dp0.."
