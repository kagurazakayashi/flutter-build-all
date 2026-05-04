@ECHO OFF
SETLOCAL
REM Build Android APK
REM Usage: run from your Flutter project root

PUSHD "%~dp0.."

ECHO Building Android...
CALL dart run flutter_build_all:build_all --target "android" --l10n=off
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: build failed.
EXIT /B 1
