@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-of-smoke-build.ps1" %*
