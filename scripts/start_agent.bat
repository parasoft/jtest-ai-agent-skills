@echo off
REM This script is used to start the Copilot agent with specific allowed paths and tools. 
REM It checks for the ANALYZED_PROJECT_PATH environment variable and sets the current location accordingly. 
REM If the ANALYZED_PROJECT_PATH environment variable is not set, it will launch the Copilot agent in the current directory.
REM The command to be executed is built from the allowed paths and tools defined in the script.

REM Enable delayed expansion for safe appending
@echo off
setlocal EnableExtensions EnableDelayedExpansion
goto :main

:prepare_copilot_cmd
REM This subroutine is used to prepare allowed  paths and tools needed for the Copilot agent.
REM --- Allowed paths (quoted) ---
REM Update these paths as needed
set "ADD_DIRS="

REM If ANALYZED_PROJECT_PATH environment variable is defined, append it (quoted)
if defined ANALYZED_PROJECT_PATH (
    set "ADD_DIRS=!ADD_DIRS! --add-dir "%ANALYZED_PROJECT_PATH%""
    cd /d "%ANALYZED_PROJECT_PATH%"
) else (
    echo Warning: ANALYZED_PROJECT_PATH environment variable is not set. Copilot agent will be launched in current directory: %CD%
    set "ADD_DIRS=!ADD_DIRS! --add-dir "%CD%""
)

REM If JTEST_HOME environment variable is defined, append it (quoted)
if defined JTEST_HOME (
    set "ADD_DIRS=!ADD_DIRS! --add-dir "%JTEST_HOME%""
    set "ADD_DIRS=!ADD_DIRS! --add-dir "%JTEST_HOME%"/integration/ai/skills"
)

REM --- Allowed and denied tools (comma-separated) ---
set "ALLOWED_TOOLS=shell,view,create,edit,write,read,grep,glob,memory"
REM set "DENIED_TOOLS=shell(git push)"
set "DENIED_TOOLS="
EXIT /B 0

:help
echo.
echo Usage: %SCRIPT_NAME% ^<agent-command^> [additional-args]
echo Example: %SCRIPT_NAME% copilot --some-flag
echo.
echo Run the specified agent command with preconfigured allowed paths and tools.
echo The allowed paths could be set in ADD_DIRS variable in this script or via --add-dir option (see :prepare_copilot_cmd subroutine).
echo The allowed and denied tools could be set in ALLOWED_TOOLS and DENIED_TOOLS variables (see :prepare_copilot_cmd subroutine).
echo.
echo Supported coding agents:
echo    copilot    GitHub Copilot CLI
echo.
echo Examples:
echo    %SCRIPT_NAME% copilot
echo    %SCRIPT_NAME% copilot --add-dir /path/to/another/allowed/dir
echo.
echo Note:
echo    The ANALYZED_PROJECT_PATH environment variable can be set to specify the main project directory for the Copilot agent.
echo    If not set, the agent will be launched in the current directory.
EXIT /B 0

:run_agent
CALL :prepare_copilot_cmd
set "COPILOT_CMD=%CMD_AGENT%.exe"
REM Compose command (use delayed expansion to include ADD_DIRS)
set "CMD=!COPILOT_CMD! !ADD_DIRS! --allow-tool "!ALLOWED_TOOLS!" --deny-tool "!DENIED_TOOLS!" %*"

REM Print the composed command for debugging (similar to set -x)
echo Running command:
echo    %CMD%
echo.

REM Execute copilot.exe with constructed args, forwarding any args passed to this script
REM Using call so that control returns to this script after copilot finishes
call !COPILOT_CMD! !ADD_DIRS! --allow-tool "!ALLOWED_TOOLS!" --deny-tool "!DENIED_TOOLS!" %*
EXIT /B 0

:main
REM --- Construct and execute the command ---
SET "SCRIPT_NAME=%~nx0"
SET "SUPPORTED_AGENTS=copilot"


IF "%~1"=="" (
    CALL :help
    EXIT /B 0
)

SET "CMD_AGENT=%~1"

IF /I "%CMD_AGENT%"=="-h" (
    CALL :help
    EXIT /B 0
)

IF /I "%CMD_AGENT%"=="--help" (
    CALL :help
    EXIT /B 0
)

shift

IF /I "%CMD_AGENT%"=="copilot" (
    CALL :run_agent
    EXIT /B 0
)

echo Error: Unknown command: "%CMD_AGENT%" >&2
echo        Supported agents: %SUPPORTED_AGENTS% 1>&2
EXIT /B 1
endlocal


