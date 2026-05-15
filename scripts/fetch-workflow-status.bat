@echo off
python "%~dp0fetch-workflow-status.py" %*
exit /b %ERRORLEVEL%
