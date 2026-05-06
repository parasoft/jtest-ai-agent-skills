@echo off
rem =============================================================================
rem resolve-config.bat  —  Load, parse, and validate all UTA Test Creation settings
rem
rem Called by the skill runner or other scripts before analysis begins.
rem After this script completes, all resolved variables are available as
rem environment variables in the calling shell (because setlocal is NOT used
rem here — the caller owns the scope).
rem
rem Usage:
rem   call "scripts\internal\resolve-config.bat" "<skill_dir>"
rem
rem Arguments:
rem   %1 — SKILL_DIR: absolute path to the skill root directory (contains SKILL.md)
rem
rem On validation failure the script prints an ERROR message and
rem exits with code 1.
rem
rem Environment variables set on success:
rem   JTEST_HOME, ANALYZED_PROJECT_PATH, JTEST_UTA_CONFIGURATION, JTEST_COMMIT_FIXES,
rem   JTEST_SETTINGS, JTEST_STATIC_BASE_REPORT, JTEST_STATIC_BASE_COVERAGE,
rem   JTEST_REFERENCE_BRANCH, GIT_WORKSPACE, GIT_BRANCH,
rem   JTEST_UTA_SCRIPT_DIR, JTEST_UTA_RESOURCE, JTEST_FIX_ATTEMPTS, JTEST_UTA_NO_OF_MAX_FIXES
rem   (set to empty string when not applicable)
rem =============================================================================

rem We intentionally do NOT use setlocal so variables propagate to the caller.
rem However we need delayed expansion for the config-file parser.
set "_RC_SKILL_DIR=%~1"
if "%_RC_SKILL_DIR%"=="" (
    echo ERROR: SKILL_DIR argument is required.
    exit /b 1
)

rem ===== Step 0: Load optional config file ====================================

rem Auto-discover config file from default locations when JTEST_SKILLS_CONFIG is not set
if not defined JTEST_SKILLS_CONFIG goto :try_default_config
if "%JTEST_SKILLS_CONFIG%"=="" goto :try_default_config
goto :validate_config
:try_default_config
if exist "%CD%\jtest-skills.config" (
    set "JTEST_SKILLS_CONFIG=%CD%\jtest-skills.config"
    echo INFO: Using config file found at default location: %CD%\jtest-skills.config
    goto :validate_config
)
if exist "%CD%\.jtest\jtest-skills.config" (
    set "JTEST_SKILLS_CONFIG=%CD%\.jtest\jtest-skills.config"
    echo INFO: Using config file found at default location: %CD%\.jtest\jtest-skills.config
    goto :validate_config
)
goto :skip_config
:validate_config
if not defined JTEST_SKILLS_CONFIG goto :skip_config
if "%JTEST_SKILLS_CONFIG%"=="" goto :skip_config
if not exist "%JTEST_SKILLS_CONFIG%" (
    echo ERROR: JTEST_SKILLS_CONFIG points to a file that does not exist: %JTEST_SKILLS_CONFIG%. Verify the path and retry.
    exit /b 1
)

for /f "usebackq tokens=1,* delims==" %%A in ("%JTEST_SKILLS_CONFIG%") do (
    setlocal enabledelayedexpansion
    set "_cfgkey=%%A"
    set "_cfgval=%%B"
    rem Skip comments (lines starting with #)
    if not "!_cfgkey:~0,1!"=="#" (
        rem Trim
        for %%K in (!_cfgkey!) do set "_cfgkey=%%K"
        rem Only set if not already defined
        if "!_cfgkey!"=="JTEST_HOME" if not defined JTEST_HOME endlocal & set "JTEST_HOME=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="ANALYZED_PROJECT_PATH" if not defined ANALYZED_PROJECT_PATH endlocal & set "ANALYZED_PROJECT_PATH=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_UTA_CONFIGURATION" if not defined JTEST_UTA_CONFIGURATION endlocal & set "JTEST_UTA_CONFIGURATION=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_COMMIT_FIXES" if not defined JTEST_COMMIT_FIXES endlocal & set "JTEST_COMMIT_FIXES=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_SETTINGS" if not defined JTEST_SETTINGS endlocal & set "JTEST_SETTINGS=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_STATIC_BASE_REPORT" if not defined JTEST_STATIC_BASE_REPORT endlocal & set "JTEST_STATIC_BASE_REPORT=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_STATIC_BASE_COVERAGE" if not defined JTEST_STATIC_BASE_COVERAGE endlocal & set "JTEST_STATIC_BASE_COVERAGE=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_UTA_SCRIPT_DIR" if not defined JTEST_UTA_SCRIPT_DIR endlocal & set "JTEST_UTA_SCRIPT_DIR=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_RESOURCE" if not defined JTEST_RESOURCE endlocal & set "JTEST_RESOURCE=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_UTA_RESOURCE" if not defined JTEST_UTA_RESOURCE endlocal & set "JTEST_UTA_RESOURCE=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_FIX_ATTEMPTS" if not defined JTEST_FIX_ATTEMPTS endlocal & set "JTEST_FIX_ATTEMPTS=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_UTA_NO_OF_MAX_FIXES" if not defined JTEST_UTA_NO_OF_MAX_FIXES endlocal & set "JTEST_UTA_NO_OF_MAX_FIXES=%%B" & setlocal enabledelayedexpansion
        if "!_cfgkey!"=="JTEST_REFERENCE_BRANCH" if not defined JTEST_REFERENCE_BRANCH endlocal & set "JTEST_REFERENCE_BRANCH=%%B" & setlocal enabledelayedexpansion
    )
    endlocal
)

:skip_config


rem ===== Step 1: Resolve required & optional settings =========================

rem ---- JTEST_HOME ------------------------------------------------------------
if defined JTEST_HOME if not "%JTEST_HOME%"=="" goto :jtest_home_ok
where jtestcli.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    for /f "delims=" %%P in ('where jtestcli.exe') do set "JTEST_HOME=%%~dpP"
    rem Strip trailing backslash
    if "%JTEST_HOME:~-1%"=="\" set "JTEST_HOME=%JTEST_HOME:~0,-1%"
    goto :jtest_home_ok
)
echo ERROR: JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry.
exit /b 1
:jtest_home_ok

rem ---- ANALYZED_PROJECT_PATH ----------------------------------------------------------
if not defined ANALYZED_PROJECT_PATH (
    echo ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.
    exit /b 1
)
if "%ANALYZED_PROJECT_PATH%"=="" (
    echo ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.
    exit /b 1
)
if not exist "%ANALYZED_PROJECT_PATH%\" (
    echo ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.
    exit /b 1
)

rem ---- JTEST_UTA_CONFIGURATION ----------------------------------------------
if not defined JTEST_UTA_CONFIGURATION set "JTEST_UTA_CONFIGURATION=builtin://Create Unit Tests"
if "%JTEST_UTA_CONFIGURATION%"=="" set "JTEST_UTA_CONFIGURATION=builtin://Create Unit Tests"

rem ---- JTEST_COMMIT_FIXES ----------------------------------------------------
if not defined JTEST_COMMIT_FIXES set "JTEST_COMMIT_FIXES=false"
if "%JTEST_COMMIT_FIXES%"=="" set "JTEST_COMMIT_FIXES=false"

rem ---- JTEST_SETTINGS --------------------------------------------------------
if defined JTEST_SETTINGS (
    if not "%JTEST_SETTINGS%"=="" (
        if not exist "%JTEST_SETTINGS%" (
            echo ERROR: JTEST_SETTINGS points to a file that does not exist: %JTEST_SETTINGS%. Verify the path and retry.
            exit /b 1
        )
    )
)
if not defined JTEST_SETTINGS set "JTEST_SETTINGS="

rem ---- JTEST_STATIC_BASE_REPORT -----------------------------------------------------
if defined JTEST_STATIC_BASE_REPORT (
    if not "%JTEST_STATIC_BASE_REPORT%"=="" (
        if not exist "%JTEST_STATIC_BASE_REPORT%" (
            echo ERROR: JTEST_STATIC_BASE_REPORT points to a file that does not exist: %JTEST_STATIC_BASE_REPORT%. Verify the path and retry.
            exit /b 1
        )
    )
)
if not defined JTEST_STATIC_BASE_REPORT set "JTEST_STATIC_BASE_REPORT="

rem ---- JTEST_STATIC_BASE_COVERAGE ---------------------------------------------------
if defined JTEST_STATIC_BASE_COVERAGE (
    if not "%JTEST_STATIC_BASE_COVERAGE%"=="" (
        if not exist "%JTEST_STATIC_BASE_COVERAGE%" (
            echo ERROR: JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: %JTEST_STATIC_BASE_COVERAGE%. Verify the path and retry.
            exit /b 1
        )
    )
)
if not defined JTEST_STATIC_BASE_COVERAGE set "JTEST_STATIC_BASE_COVERAGE="

rem ---- JTEST_UTA_SCRIPT_DIR ------------------------------------------------------------
set "_RC_SCRIPT_DIR_SOURCE=(default)"
if not defined JTEST_UTA_SCRIPT_DIR (
    set "JTEST_UTA_SCRIPT_DIR=%_RC_SKILL_DIR%\scripts"
) else if "%JTEST_UTA_SCRIPT_DIR%"=="" (
    set "JTEST_UTA_SCRIPT_DIR=%_RC_SKILL_DIR%\scripts"
) else (
    set "_RC_SCRIPT_DIR_SOURCE=(override)"
)

if not exist "%JTEST_UTA_SCRIPT_DIR%\" (
    echo ERROR: JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: %JTEST_UTA_SCRIPT_DIR%. Verify the path and retry.
    exit /b 1
)

rem Validate required scripts exist (prefer .bat, then .ps1)
set "_RC_BV_OK=0"
if exist "%JTEST_UTA_SCRIPT_DIR%\build-verify\build-verify.bat" set "_RC_BV_OK=1"
if exist "%JTEST_UTA_SCRIPT_DIR%\build-verify\build-verify.ps1" set "_RC_BV_OK=1"
if "%_RC_BV_OK%"=="0" (
    echo ERROR: JTEST_UTA_SCRIPT_DIR=%JTEST_UTA_SCRIPT_DIR% is missing required script build-verify.bat ^(or .ps1^). Provide both build-verify and jtest-analyze scripts and retry.
    exit /b 1
)

set "_RC_JA_OK=0"
if exist "%JTEST_UTA_SCRIPT_DIR%\jtest-analyze\jtest-analyze.bat" set "_RC_JA_OK=1"
if exist "%JTEST_UTA_SCRIPT_DIR%\jtest-analyze\jtest-analyze.ps1" set "_RC_JA_OK=1"
if "%_RC_JA_OK%"=="0" (
    echo ERROR: JTEST_UTA_SCRIPT_DIR=%JTEST_UTA_SCRIPT_DIR% is missing required script jtest-analyze.bat ^(or .ps1^). Provide both build-verify and jtest-analyze scripts and retry.
    exit /b 1
)

rem ---- JTEST_RESOURCE (set by the skill before calling; default to empty) ----
if not defined JTEST_RESOURCE set "JTEST_RESOURCE="

rem ---- JTEST_UTA_RESOURCE -- UTA scope for testing (set by the skill before calling; default to empty) ------
if not defined JTEST_UTA_RESOURCE set "JTEST_UTA_RESOURCE="

rem ---- JTEST_FIX_ATTEMPTS -- Number of extra attempts to fix the test -----------
if not defined JTEST_FIX_ATTEMPTS set "JTEST_FIX_ATTEMPTS=3"

rem ---- JTEST_UTA_NO_OF_MAX_FIXES -- Limit the application of fixes for test -----------
if not defined JTEST_UTA_NO_OF_MAX_FIXES set "JTEST_UTA_NO_OF_MAX_FIXES="

rem ---- JTEST_REFERENCE_BRANCH (optional) ----------------------------------------
if not defined JTEST_REFERENCE_BRANCH set "JTEST_REFERENCE_BRANCH="

rem Ensure git context variables do not carry stale values between runs
set "GIT_BRANCH="
set "GIT_WORKSPACE="

rem Resolve git context and validate target branch when JTEST_REFERENCE_BRANCH is set
if defined JTEST_REFERENCE_BRANCH (
    if not "%JTEST_REFERENCE_BRANCH%"=="" (
        where git >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: JTEST_REFERENCE_BRANCH is set, but git is not available on PATH. Install git or unset JTEST_REFERENCE_BRANCH.
            exit /b 1
        )

        git -C "%ANALYZED_PROJECT_PATH%" rev-parse --is-inside-work-tree >nul 2>&1
        if %ERRORLEVEL% neq 0 (
            echo ERROR: JTEST_REFERENCE_BRANCH is set, but the solution directory is not inside a git repository: %ANALYZED_PROJECT_PATH%
            exit /b 1
        )

        for /f "delims=" %%W in ('git -C "%ANALYZED_PROJECT_PATH%" rev-parse --show-toplevel 2^>nul') do set "GIT_WORKSPACE=%%W"
        if not defined GIT_WORKSPACE (
            echo ERROR: Failed to determine git workspace for solution directory: %ANALYZED_PROJECT_PATH%
            exit /b 1
        )

        for /f "delims=" %%B in ('git -C "%ANALYZED_PROJECT_PATH%" rev-parse --abbrev-ref HEAD 2^>nul') do set "GIT_BRANCH=%%B"
        if not defined GIT_BRANCH (
            echo ERROR: Failed to determine current git branch for solution directory: %ANALYZED_PROJECT_PATH%
            exit /b 1
        )

        set "_RC_HAS_TARGET=0"
        git -C "%ANALYZED_PROJECT_PATH%" show-ref --verify --quiet "refs/heads/%JTEST_REFERENCE_BRANCH%" >nul 2>&1
        if %ERRORLEVEL% equ 0 set "_RC_HAS_TARGET=1"
        if "!_RC_HAS_TARGET!"=="0" (
            for /f "delims=" %%R in ('git -C "%ANALYZED_PROJECT_PATH%" for-each-ref --format^="^%^(refname^)" "refs/remotes/*/%JTEST_REFERENCE_BRANCH%" 2^>nul') do set "_RC_HAS_TARGET=1"
        )
        if "!_RC_HAS_TARGET!"=="0" (
            echo ERROR: JTEST_REFERENCE_BRANCH '%JTEST_REFERENCE_BRANCH%' does not exist in the repository.
            exit /b 1
        )
    )
)

rem ===== Step 2: Verify Jtest installation ====================================
if not exist "%JTEST_HOME%\jtestcli.exe" (
    echo ERROR: jtestcli not found in JTEST_HOME=%JTEST_HOME%. Verify the Jtest installation path.
    exit /b 1
)

rem ===== Print resolved configuration =========================================
echo.
echo Resolved configuration:
if defined JTEST_SKILLS_CONFIG (
    echo   JTEST_SKILLS_CONFIG          = %JTEST_SKILLS_CONFIG%
) else (
    echo   JTEST_SKILLS_CONFIG          = (not set^)
)
echo   JTEST_HOME               = %JTEST_HOME%
echo   ANALYZED_PROJECT_PATH             = %ANALYZED_PROJECT_PATH%
echo   JTEST_UTA_CONFIGURATION  = %JTEST_UTA_CONFIGURATION%
echo   JTEST_COMMIT_FIXES       = %JTEST_COMMIT_FIXES%
if "%JTEST_SETTINGS%"=="" (
    echo   JTEST_SETTINGS           = (not set^)
) else (
    echo   JTEST_SETTINGS           = %JTEST_SETTINGS%
)
if "%JTEST_STATIC_BASE_REPORT%"=="" (
    echo   JTEST_STATIC_BASE_REPORT        = (not set^)
) else (
    echo   JTEST_STATIC_BASE_REPORT        = %JTEST_STATIC_BASE_REPORT%
)
if "%JTEST_STATIC_BASE_COVERAGE%"=="" (
    echo   JTEST_STATIC_BASE_COVERAGE      = (not set^)
) else (
    echo   JTEST_STATIC_BASE_COVERAGE      = %JTEST_STATIC_BASE_COVERAGE%
)
echo   JTEST_UTA_SCRIPT_DIR               = %JTEST_UTA_SCRIPT_DIR% %_RC_SCRIPT_DIR_SOURCE%
if "%JTEST_RESOURCE%"=="" (
    echo   ANALYSIS_SCOPE           = (none -- full project^)
) else (
    echo   ANALYSIS_SCOPE           = %JTEST_RESOURCE%
)
if "%JTEST_UTA_RESOURCE%"=="" (
    echo   JTEST_UTA_RESOURCE        = (not set^)
) else (
    echo   JTEST_UTA_RESOURCE        = %JTEST_UTA_RESOURCE%
)
if "%JTEST_FIX_ATTEMPTS%"=="" (
    echo   JTEST_FIX_ATTEMPTS        = (not set^)
) else (
    echo   JTEST_FIX_ATTEMPTS        = %JTEST_FIX_ATTEMPTS%
)
if "%JTEST_UTA_NO_OF_MAX_FIXES%"=="" (
    echo   JTEST_UTA_NO_OF_MAX_FIXES          = (not set^)
) else (
    echo   JTEST_UTA_NO_OF_MAX_FIXES          = %JTEST_UTA_NO_OF_MAX_FIXES%
)
if "%JTEST_REFERENCE_BRANCH%"=="" (
    echo   JTEST_REFERENCE_BRANCH       = (not set^)
) else (
    echo   JTEST_REFERENCE_BRANCH       = %JTEST_REFERENCE_BRANCH%
)
if "%GIT_WORKSPACE%"=="" (
    echo   GIT_WORKSPACE                = (not set^)
) else (
    echo   GIT_WORKSPACE                = %GIT_WORKSPACE%
)
if "%GIT_BRANCH%"=="" (
    echo   GIT_BRANCH                   = (not set^)
) else (
    echo   GIT_BRANCH                   = %GIT_BRANCH%
)
echo.

rem Clean up internal variables
set "_RC_SKILL_DIR="
set "_RC_SCRIPT_DIR_SOURCE="
set "_RC_BV_OK="
set "_RC_JA_OK="
set "_RC_HAS_TARGET="

exit /b 0

