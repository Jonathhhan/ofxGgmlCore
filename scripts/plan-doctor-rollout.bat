@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "PLAN_PS1=%SCRIPT_DIR%plan-doctor-rollout.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%PLAN_PS1%" %*
exit /b %ERRORLEVEL%
