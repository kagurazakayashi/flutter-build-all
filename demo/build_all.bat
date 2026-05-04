@ECHO OFF
SETLOCAL
REM Build all available platforms with default options
REM Usage: run from your Flutter project root

PUSHD "%~dp0.."

ECHO Building all platforms...
CALL dart run flutter_build_all:build_all
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: build failed.
EXIT /B 1
