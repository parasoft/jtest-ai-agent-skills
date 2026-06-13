@echo off
rem =============================================================================
rem jtest-analyze.bat  —  Run Jtest static analysis
rem
rem Called by the Jtest Static Analysis skill (always, via JTEST_STATIC_SCRIPT_DIR).
rem
rem Environment variables provided by the skill (always set before this script
rem is invoked):
rem   JTEST_HOME               – Jtest installation directory
rem   ANALYZED_PROJECT_PATH             – Absolute path to the project root
rem   JTEST_STATIC_CONFIGURATION – Jtest test configuration name
rem   JTEST_SETTINGS           – Absolute path to Jtest settings file (may be empty)
rem   JTEST_RESOURCE           – Comma-separated resource patterns, e.g.
rem                              "**/com/foo/**,**/Bar.java" (may be empty for
rem                              full-project analysis). Passed as a single
rem                              -Djtest.resources switch.
rem   JTEST_REF_REPORT_FILE    – Absolute path to the baseline report.xml used for
rem                              fix-verification runs (empty during initial analysis)
rem   JTEST_REF_REPORT_EXCLUDE – Set to "false" during fix-verification runs to
rem                              include all findings relative to the baseline
rem                              (empty during initial analysis)
rem   JTEST_REFERENCE_BRANCH   – When set, restricts analysis scope to changes
rem                              relative to the specified target branch (git).
rem                              GIT_WORKSPACE and GIT_BRANCH must also be set
rem                              (resolved automatically by resolve-config).
rem
rem Exit codes:
rem   0  – Analysis completed successfully; report.xml produced
rem   1  – Analysis failed
rem
rem On success, always prints as its last stdout line:
rem   REPORT_XML=<absolute_path_to_report.xml>
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
rem Build the reference-report arguments (set only during fix-verification runs)
rem ---------------------------------------------------------------------------
set REF_REPORT_ARG=
if defined JTEST_REF_REPORT_FILE (
    if not "%JTEST_REF_REPORT_FILE%"=="" (
        set REF_REPORT_ARG=-Dproperty.goal.ref.report.file="%JTEST_REF_REPORT_FILE%"
    )
)

set REF_EXCLUDE_ARG=
if defined JTEST_REF_REPORT_EXCLUDE (
    if not "%JTEST_REF_REPORT_EXCLUDE%"=="" (
        set REF_EXCLUDE_ARG=-Dproperty.goal.ref.report.findings.exclude=%JTEST_REF_REPORT_EXCLUDE%
    )
)

rem ---------------------------------------------------------------------------
rem Build -Djtest.resources argument from JTEST_RESOURCE (comma-separated)
rem ---------------------------------------------------------------------------
set RESOURCE_ARGS=
if defined JTEST_RESOURCE (
    if not "%JTEST_RESOURCE%"=="" (
        set RESOURCE_ARGS=-Djtest.resources="%JTEST_RESOURCE%"
    )
)

rem ---------------------------------------------------------------------------
rem Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
rem ---------------------------------------------------------------------------
set BRANCH_ARGS=
if defined JTEST_REFERENCE_BRANCH (
    if not "%JTEST_REFERENCE_BRANCH%"=="" (
        set BRANCH_ARGS=-Dproperty.scope.scontrol=true -Dproperty.scope.scontrol.files.filter.mode=branch -Dproperty.scontrol.rep1.type=git -Dproperty.scontrol.rep1.git.workspace="%GIT_WORKSPACE%" -Dproperty.scontrol.rep1.git.branch="%GIT_BRANCH%" -Dproperty.scope.scontrol.ref.branch="%JTEST_REFERENCE_BRANCH%"
    )
)

rem ---------------------------------------------------------------------------
rem Build the OSGi cache ID argument (set by each subagent to avoid conflicts
rem when multiple agents run jtestcli concurrently)
rem ---------------------------------------------------------------------------
set CACHE_ID_ARG=
if defined JTEST_CACHE_ID (
    if not "%JTEST_CACHE_ID%"=="" (
        set CACHE_ID_ARG=-Djtest.jvmArgs=-Djt.cache.id="%JTEST_CACHE_ID%"
    )
)

rem ---------------------------------------------------------------------------
rem Detect build wrapper / fall back to system tool
rem ---------------------------------------------------------------------------
set BUILD_CMD=
set BUILD_TYPE=

if exist "gradlew.bat" (
    set BUILD_CMD=.\gradlew.bat
    set BUILD_TYPE=gradle
) else if exist "mvnw.cmd" (
    set BUILD_CMD=.\mvnw.cmd
    set BUILD_TYPE=maven
) else (
    where gradle >nul 2>&1
    if not errorlevel 1 (
        if exist "build.gradle" (
            set BUILD_CMD=gradle
            set BUILD_TYPE=gradle
        )
    )
)
if not defined BUILD_CMD (
    where mvn >nul 2>&1
    if not errorlevel 1 (
        if exist "pom.xml" (
            set BUILD_CMD=mvn
            set BUILD_TYPE=maven
        )
    )
)

if not defined BUILD_CMD (
    echo ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH.
    exit /b 1
)

echo [jtest-analyze] Using build command: %BUILD_CMD% ^(type: %BUILD_TYPE%^)

rem ---------------------------------------------------------------------------
rem Run Jtest analysis
rem ---------------------------------------------------------------------------
if "%BUILD_TYPE%"=="maven" (
    call %BUILD_CMD% jtest:jtest ^
        -Djtest.config="%JTEST_STATIC_CONFIGURATION%" ^
        %SETTINGS_ARG% ^
        %REF_REPORT_ARG% ^
        %REF_EXCLUDE_ARG% ^
        %RESOURCE_ARGS% ^
        %BRANCH_ARGS% ^
        %CACHE_ID_ARG%
) else (
    call %BUILD_CMD% jtest ^
        "-I%JTEST_HOME%\integration\gradle\init.gradle" ^
        -Djtest.config="%JTEST_STATIC_CONFIGURATION%" ^
        %SETTINGS_ARG% ^
        %REF_REPORT_ARG% ^
        %REF_EXCLUDE_ARG% ^
        %RESOURCE_ARGS% ^
        %BRANCH_ARGS% ^
        %CACHE_ID_ARG%
)

set EXIT_CODE=%ERRORLEVEL%

if %EXIT_CODE% neq 0 (
    echo ERROR: Jtest analysis exited with code %EXIT_CODE%.
    exit /b %EXIT_CODE%
)

rem ---------------------------------------------------------------------------
rem Resolve, verify, and emit the report path
rem ---------------------------------------------------------------------------
if "!BUILD_TYPE!"=="maven" (
    set "REPORT_XML=!ANALYZED_PROJECT_PATH!\target\jtest\report.xml"
) else (
    set "REPORT_XML=!ANALYZED_PROJECT_PATH!\build\jtest\report.xml"
    if not exist "!REPORT_XML!" (
        set "REPORT_XML=!ANALYZED_PROJECT_PATH!\build\reports\jtest\report.xml"
    )
)

if not exist "!REPORT_XML!" (
    echo ERROR: report.xml not found at expected location: !REPORT_XML!
    exit /b 1
)

echo [jtest-analyze] Analysis completed successfully.
echo REPORT_XML=!REPORT_XML!
exit /b 0
