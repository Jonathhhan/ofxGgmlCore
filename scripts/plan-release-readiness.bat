@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-release-readiness.ps1" %*
