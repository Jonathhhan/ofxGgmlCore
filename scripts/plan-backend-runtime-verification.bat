@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-backend-runtime-verification.ps1" %*

