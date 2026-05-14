@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-smoke-build-target-handoff.ps1" %*
