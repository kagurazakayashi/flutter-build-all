@ECHO OFF
SETLOCAL
REM Build assets only: l10n and app icons (no platform build)
REM Usage: run from your Flutter project root
REM Requires: icon source files in ico/ directory (ico/iconf.png, ico/iconb.png)

SET "PROJECT_DIR=%~dp0.."
PUSHD "%PROJECT_DIR%"

ECHO Building assets...
CALL flutter gen-l10n
IF ERRORLEVEL 1 GOTO :error

PUSHD "flutter-icon-creator"
CALL dart run flutter_icon_creator:flutter_icon_creator -f "%PROJECT_DIR%" -i "%PROJECT_DIR%\ico\iconf.png" -b "%PROJECT_DIR%\ico\iconb.png"
POPD
IF ERRORLEVEL 1 GOTO :error

POPD
ECHO Done.
EXIT /B 0

:error
POPD
ECHO Error: assets build failed.
EXIT /B 1
