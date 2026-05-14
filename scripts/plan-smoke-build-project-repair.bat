@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-smoke-build-project-repair.ps1" %*
