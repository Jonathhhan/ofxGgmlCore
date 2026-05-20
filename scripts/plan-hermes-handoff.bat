@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0plan-hermes-handoff.ps1" %*
