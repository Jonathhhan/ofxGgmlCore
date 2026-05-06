@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "ADDON_ROOT=%SCRIPT_DIR%.."
set "DEST_DIR=%ADDON_ROOT%\libs\sam.cpp"
if "%OFXGGML_SAM_CPP_REPO%"=="" set "OFXGGML_SAM_CPP_REPO=https://github.com/YavorGIvanov/sam.cpp.git"
if "%OFXGGML_SAM_CPP_REF%"=="" set "OFXGGML_SAM_CPP_REF=81002818eb0e2cb3b9a523286b067f80f8424431"

where git >nul 2>nul
if errorlevel 1 (
	echo git is required to install sam.cpp
	exit /b 1
)

if not exist "%ADDON_ROOT%\libs" mkdir "%ADDON_ROOT%\libs"

if exist "%DEST_DIR%\.git" (
	echo ==^> Updating existing sam.cpp checkout in %DEST_DIR%
	git -C "%DEST_DIR%" fetch --tags origin
) else (
	if exist "%DEST_DIR%" (
		for /f %%A in ('dir /b "%DEST_DIR%" 2^>nul') do (
			echo Refusing to overwrite non-empty directory: %DEST_DIR%
			exit /b 1
		)
	)
	if exist "%DEST_DIR%" rmdir "%DEST_DIR%"
	echo ==^> Cloning sam.cpp into %DEST_DIR%
	git clone --recursive "%OFXGGML_SAM_CPP_REPO%" "%DEST_DIR%"
)

git -C "%DEST_DIR%" checkout "%OFXGGML_SAM_CPP_REF%"
if errorlevel 1 exit /b 1
git -C "%DEST_DIR%" submodule update --init --recursive
if errorlevel 1 exit /b 1

echo ==^> sam.cpp is installed.
echo Source: %DEST_DIR%
echo Ref:    %OFXGGML_SAM_CPP_REF%
echo Note: this source is not compiled automatically because the pinned checkout targets older ggml allocator APIs.
echo Use the preview backend by default, or define OFXGGML_ENABLE_SAMCPP_ADAPTER=1 and link a ggml-compatible SAM implementation.
echo Regenerate ofxGgmlSamExample with the openFrameworks Project Generator after changing addon_config.mk or project sources.

endlocal
