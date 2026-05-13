@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "CLEANUP_PS1=%SCRIPT_DIR%plan-agent-branch-cleanup.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%CLEANUP_PS1%" %*
exit /b %ERRORLEVEL%
