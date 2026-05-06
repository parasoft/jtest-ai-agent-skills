@echo off
rem =============================================================================
rem run-script.bat  —  OS-dispatch helper: invoke a named script from JTEST_STATIC_SCRIPT_DIR
rem
rem Usage:
rem   call "%JTEST_STATIC_SCRIPT_DIR%\internal\run-script.bat" <script-name>
rem
rem Arguments:
rem   %1 — script name: "build-verify" or "jtest-analyze"
rem
rem Requires:
rem   JTEST_STATIC_SCRIPT_DIR — set by resolve-config.bat before this helper is called
rem
rem Behaviour:
rem   Prefers <JTEST_STATIC_SCRIPT_DIR>\<name>\<name>.bat; falls back to .ps1.
rem   Propagates the script's exit code to the caller unchanged.
rem
rem Exit codes:
rem   As returned by the invoked script.
rem   1 — script name missing, JTEST_STATIC_SCRIPT_DIR not set, or script file not found.
rem =============================================================================

setlocal enabledelayedexpansion

set "_RS_NAME=%~1"
if "%_RS_NAME%"=="" (
    echo ERROR: [run-script] Script name argument is required ^(e.g. build-verify^).
    exit /b 1
)

if not defined JTEST_STATIC_SCRIPT_DIR (
    echo ERROR: [run-script] JTEST_STATIC_SCRIPT_DIR is not set. Run resolve-config first.
    exit /b 1
)
if "%JTEST_STATIC_SCRIPT_DIR%"=="" (
    echo ERROR: [run-script] JTEST_STATIC_SCRIPT_DIR is not set. Run resolve-config first.
    exit /b 1
)

set "_RS_BAT=%JTEST_STATIC_SCRIPT_DIR%\%_RS_NAME%\%_RS_NAME%.bat"
set "_RS_PS1=%JTEST_STATIC_SCRIPT_DIR%\%_RS_NAME%\%_RS_NAME%.ps1"

if exist "!_RS_BAT!" (
    echo [run-script] %_RS_NAME%
    endlocal
    call "%JTEST_STATIC_SCRIPT_DIR%\%_RS_NAME%\%_RS_NAME%.bat"
    exit /b %ERRORLEVEL%
)

if exist "!_RS_PS1!" (
    echo [run-script] %_RS_NAME%
    endlocal
    powershell -ExecutionPolicy Bypass -File "%JTEST_STATIC_SCRIPT_DIR%\%_RS_NAME%\%_RS_NAME%.ps1"
    exit /b %ERRORLEVEL%
)

echo ERROR: [run-script] Script not found: %_RS_BAT% ^(or .ps1^)
exit /b 1

