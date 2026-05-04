@ECHO OFF
SETLOCAL
REM Test the build environment without performing a build
REM Usage: run from your Flutter project root

PUSHD "%~dp0.."

ECHO Testing build environment...
CALL dart run flutter_build_all:build_all --test
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: environment test failed.
EXIT /B 1
