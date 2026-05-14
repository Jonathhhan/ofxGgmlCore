@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0check-ecosystem-readiness.ps1" %*
