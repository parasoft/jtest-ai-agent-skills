@echo off
rem =============================================================================
rem jtest-analyze.bat  —  Template for running UTA tests creation
rem
rem Called by the UTA Test Creation skill (always, via SCRIPT_DIR).
rem
rem Environment variables provided by the skill (always set before this script
rem is invoked):
rem   JTEST_HOME               – Jtest installation directory
rem   ANALYZED_PROJECT_PATH    – Absolute path to the project root
rem   JTEST_UTA_CONFIGURATION  – Jtest test configuration name
rem   JTEST_SETTINGS           – Absolute path to Jtest settings file (may be empty)
rem   JTEST_UTA_RESOURCE       - Pattern to narrow down the scope to test
rem   JTEST_REFERENCE_BRANCH   – When set, restricts analysis scope to changes
rem                              relative to the specified target branch (git).
rem                              GIT_WORKSPACE and GIT_BRANCH must also be set
rem                              (resolved automatically by resolve-config).
rem
rem Exit codes:
rem   0  – Analysis completed successfully; report.xml produced
rem   1  – Analysis failed
rem
rem =============================================================================

setlocal enabledelayedexpansion

echo [jtest-analyze] ANALYZED_PROJECT_PATH = %ANALYZED_PROJECT_PATH%
echo [jtest-analyze] JTEST_HOME   = %JTEST_HOME%

cd /d "%ANALYZED_PROJECT_PATH%" || (
    echo ERROR: Cannot change to ANALYZED_PROJECT_PATH=%ANALYZED_PROJECT_PATH%
    exit /b 1
)

rem ---------------------------------------------------------------------------
rem Build the -Djtest.settings argument (omit when JTEST_SETTINGS is empty)
rem ---------------------------------------------------------------------------
set SETTINGS_ARG=
if defined JTEST_SETTINGS (
    if not "%JTEST_SETTINGS%"=="" (
        set SETTINGS_ARG=-Djtest.settings="%JTEST_SETTINGS%"
    )
)

rem ---------------------------------------------------------------------------
rem Build the -Djtest.resources argument (omit when JTEST_UTA_RESOURCE is empty)
rem ---------------------------------------------------------------------------
set SCOPE_ARG=
if defined JTEST_UTA_RESOURCE (
    if not "%JTEST_UTA_RESOURCE%"=="" (
        set SCOPE_ARG=-Djtest.resources="%JTEST_UTA_RESOURCE%"
    )
)


rem ---------------------------------------------------------------------------
rem Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
rem ---------------------------------------------------------------------------
set BRANCH_ARGS=
if defined JTEST_REFERENCE_BRANCH (
    if not "%JTEST_REFERENCE_BRANCH%"=="" (
        set BRANCH_ARGS=^
        -Dproperty.scope.scontrol=true ^
        -Dproperty.scope.scontrol.files.filter.mode=branch ^
        -Dproperty.scope.scontrol.lines.filter.mode=branch ^
        -Dproperty.scontrol.rep1.type=git ^
        -Dproperty.scontrol.rep1.git.workspace="%GIT_WORKSPACE%" ^
        -Dproperty.scontrol.rep1.git.branch="%GIT_BRANCH%" ^
        -Dproperty.scope.scontrol.ref.branch="%JTEST_REFERENCE_BRANCH%"
    )
)

rem ---------------------------------------------------------------------------
rem Detect build wrapper / fall back to system tool
rem ---------------------------------------------------------------------------
if exist "mvnw.cmd" (
    set BUILD_CMD=.\mvnw.cmd
    set BUILD_TYPE=maven
) else if exist "gradlew.bat" (
    set BUILD_CMD=.\gradlew.bat
    set BUILD_TYPE=gradle
) else (
    if exist "pom.xml" (
        where mvn >nul 2>&1 && (
            set BUILD_CMD=mvn
            set BUILD_TYPE=maven
        )
    ) else (
        where mvn >nul 2>&1 && (
            set BUILD_CMD=mvn
            set BUILD_TYPE=maven
        )
        if not defined BUILD_CMD (
            where gradle >nul 2>&1 && (
                set BUILD_CMD=gradle
                set BUILD_TYPE=gradle
            )
        )
    )
)

if not defined BUILD_CMD (
    echo ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH.
    exit /b 1
)

echo [jtest-analyze] Using build command: %BUILD_CMD% (type: %BUILD_TYPE%)

rem ---------------------------------------------------------------------------
rem Run Jtest analysis — customise arguments below for your project
rem ---------------------------------------------------------------------------
if "%BUILD_TYPE%"=="maven" (
    call %BUILD_CMD% jtest:jtest ^
        -Djtest.config="%JTEST_UTA_CONFIGURATION%" ^
        %SETTINGS_ARG% ^
        %SCOPE_ARG% ^
        %BRANCH_ARGS%
) else (
    call %BUILD_CMD% jtest ^
        -I"%JTEST_HOME%\integration\gradle\init.gradle" ^
        -Djtest.config="%JTEST_UTA_CONFIGURATION%" ^
        %SETTINGS_ARG% ^
        %SCOPE_ARG% ^
        %BRANCH_ARGS%
)

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% neq 0 (
    echo ERROR: Jtest analysis exited with code %EXIT_CODE%.
    exit /b %EXIT_CODE%
)

echo [jtest-analyze] Analysis completed successfully.
exit /b 0

