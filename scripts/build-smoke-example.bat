@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0build-smoke-example.ps1" %*
