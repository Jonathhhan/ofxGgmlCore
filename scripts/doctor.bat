@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "DOCTOR_PS1=%SCRIPT_DIR%doctor.ps1"

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%DOCTOR_PS1%" %*
exit /b %ERRORLEVEL%
