@echo off
powershell -ExecutionPolicy Bypass -NoProfile -File "%~dp0start-hermes-agent.ps1" %*
