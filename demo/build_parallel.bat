@ECHO OFF
SETLOCAL
REM Build all platforms in parallel
REM Usage: run from your Flutter project root

PUSHD "%~dp0.."

ECHO Building all platforms in parallel...
CALL dart run flutter_build_all:build_all --jobs 0 --l10n=off --analyze=off
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: build failed.
EXIT /B 1
