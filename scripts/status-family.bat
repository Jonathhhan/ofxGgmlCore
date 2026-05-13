@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "STATUS_PS1=%SCRIPT_DIR%status-family.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%STATUS_PS1%" %*
exit /b %ERRORLEVEL%
