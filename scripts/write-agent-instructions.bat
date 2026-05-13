@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "AGENT_PS1=%SCRIPT_DIR%write-agent-instructions.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%AGENT_PS1%" %*
exit /b %ERRORLEVEL%
