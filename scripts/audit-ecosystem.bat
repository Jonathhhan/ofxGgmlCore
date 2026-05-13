@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0audit-ecosystem.ps1" %*
