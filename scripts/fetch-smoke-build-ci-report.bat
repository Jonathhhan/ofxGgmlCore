@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0fetch-smoke-build-ci-report.ps1" %*
