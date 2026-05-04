@ECHO OFF
SETLOCAL
REM Build Web with embedded fonts and custom base href
REM Usage: run from your Flutter project root
REM Modify --web-base-href to match your deployment path

PUSHD "%~dp0.."

ECHO Building Web...
CALL dart run flutter_build_all:build_all --target "web" --web-embed-fonts=on --web-base-href "/" --l10n=off
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: build failed.
EXIT /B 1
