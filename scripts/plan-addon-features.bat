@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-addon-features.ps1" %*
