@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0assert-release-readiness.ps1" %*
