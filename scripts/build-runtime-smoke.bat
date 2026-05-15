@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-runtime-smoke.ps1" %*
