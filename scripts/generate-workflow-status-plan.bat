@echo off
python "%~dp0generate-workflow-status-plan.py" %*
exit /b %ERRORLEVEL%
