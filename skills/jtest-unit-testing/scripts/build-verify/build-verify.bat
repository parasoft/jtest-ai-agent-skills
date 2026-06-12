@echo off
rem =============================================================================
rem build-verify.bat  —  Build the project and run unit tests
rem
rem Called by the UTA Test Creation skill (always, via SCRIPT_DIR).
rem
rem Environment variables provided by the skill (always set before this script
rem is invoked):
rem   ANALYZED_PROJECT_PATH             – Absolute path to the project root
rem   JTEST_STATIC_BASE_REPORT             – Absolute path to base report.xml for TIA (may be empty)
rem   JTEST_STATIC_BASE_COVERAGE           – Absolute path to base coverage.xml for TIA (may be empty)
rem
rem Behaviour:
rem   - When both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE are set, runs only
rem     the tests affected by changes (TIA mode).
rem   - Otherwise runs all tests.
rem
rem Exit codes:
rem   0  – Build and all unit tests passed
rem   1  – Build failed or one or more tests failed
rem =============================================================================

setlocal enabledelayedexpansion

echo [build-verify] ANALYZED_PROJECT_PATH = %ANALYZED_PROJECT_PATH%

cd /d "%ANALYZED_PROJECT_PATH%" || (
    echo ERROR: Cannot change to ANALYZED_PROJECT_PATH=%ANALYZED_PROJECT_PATH%
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Detect build wrapper / fall back to system tool
rem ---------------------------------------------------------------------------
set BUILD_CMD=
set BUILD_TYPE=

set "TEST_CMD=test"
set TEST_CMD_ARG=%~1

if exist "mvnw.cmd" (
    set BUILD_CMD=.\mvnw.cmd
    set BUILD_TYPE=maven
) else if exist "gradlew.bat" (
    set BUILD_CMD=.\gradlew.bat
    set BUILD_TYPE=gradle
) else (
    where mvn >nul 2>&1 && if exist "%ANALYZED_PROJECT_PATH%\pom.xml" (
        set BUILD_CMD=mvn
        set BUILD_TYPE=maven
    )
    if not defined BUILD_CMD (
        where gradle >nul 2>&1 && if exist "%ANALYZED_PROJECT_PATH%\build.gradle" (
            set BUILD_CMD=gradle
            set BUILD_TYPE=gradle
        )
    )
)

rem ---------------------------------------------------------------------------
rem Resolve test command argument for specific tests if provided
rem ---------------------------------------------------------------------------
if not "%TEST_CMD_ARG%"=="" (
    if "%BUILD_TYPE%"=="maven" (
        set "TEST_CMD=!TEST_CMD! -Dtest=%TEST_CMD_ARG%"
    ) else if "%BUILD_TYPE%"=="gradle" (
        set "TEST_CMD=!TEST_CMD! --tests %TEST_CMD_ARG%"
    )
)

if not defined BUILD_CMD (
    echo ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH.
    exit /b 1
)

echo [build-verify] Using build command: %BUILD_CMD% ^(type: %BUILD_TYPE%^)

rem ---------------------------------------------------------------------------
rem Decide whether to run TIA or full tests
rem ---------------------------------------------------------------------------
set RUN_TIA=0
if defined JTEST_STATIC_BASE_REPORT (
    if defined JTEST_STATIC_BASE_COVERAGE (
        if "%TEST_CMD_ARG%"=="" (
            set RUN_TIA=1
        )
    )
)

rem ---------------------------------------------------------------------------
rem Run tests
rem ---------------------------------------------------------------------------
if "%RUN_TIA%"=="1" (
    echo [build-verify] Running in TIA mode...
    if "%BUILD_TYPE%"=="maven" (
        call %BUILD_CMD% clean tia:affected-tests test ^
            -Djtest.referenceCoverageFile="%JTEST_STATIC_BASE_COVERAGE%" ^
            -Djtest.referenceReportFile="%JTEST_STATIC_BASE_REPORT%"
    ) else (
        call %BUILD_CMD% clean --no-daemon affectedTests test ^
            -I"%JTEST_HOME%\integration\gradle\init.gradle" ^
            -Djtest.referenceCoverageFile="%JTEST_STATIC_BASE_COVERAGE%" ^
            -Djtest.referenceReportFile="%JTEST_STATIC_BASE_REPORT%"
    )
) else (
    if not "%TEST_CMD_ARG%"=="" (
        echo [build-verify] Running specified tests: %TEST_CMD_ARG%...
    ) else (
        echo [build-verify] Running all tests...
    )
    call %BUILD_CMD% %TEST_CMD%
)

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% neq 0 (
    echo ERROR: Build or unit tests failed with exit code %EXIT_CODE%.
    exit /b %EXIT_CODE%
)

echo [build-verify] Build and tests passed.
exit /b 0

