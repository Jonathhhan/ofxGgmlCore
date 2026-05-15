@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
set "SMOKE_BUILD_CI_PS1=%SCRIPT_DIR%run-smoke-build-ci.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SMOKE_BUILD_CI_PS1%" %*
exit /b %ERRORLEVEL%
