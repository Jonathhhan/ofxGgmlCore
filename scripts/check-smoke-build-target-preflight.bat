@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0check-smoke-build-target-preflight.ps1" %*
