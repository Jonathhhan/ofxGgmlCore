@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0select-smoke-build-target.ps1" %*
