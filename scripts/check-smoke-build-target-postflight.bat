@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0check-smoke-build-target-postflight.ps1" %*
