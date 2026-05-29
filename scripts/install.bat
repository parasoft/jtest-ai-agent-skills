@echo off
setlocal EnableExtensions EnableDelayedExpansion

SET "SCRIPT_NAME=%~nx0"
SET "MCP_SERVER_NAME=jtestmcp"
SET "SUPPORTED_AGENTS=codex-cli, copilot-cli"

REM ── Derive AI_HOME (parent of the scripts folder) from script location ────
FOR %%I IN ("%~dp0..") DO SET "AI_HOME=%%~fI"

IF "%~1"=="" (
    CALL :usage
    EXIT /B 0
)

SET "overall_exit=0"
SET "AGENTS_TO_INSTALL="

REM ── Parse all arguments ────────────────────────────────────────────────────
:arg_loop
    IF "%~1"=="" GOTO :end_arg_loop
    IF /I "%~1"=="-h"           CALL :usage & GOTO :next_arg
    IF /I "%~1"=="--help"       CALL :usage & GOTO :next_arg
    IF /I "%~1"=="--jtest.home" (
        IF "%~2"=="" (
            echo Error: --jtest.home requires a path value 1>&2
            SET "overall_exit=1"
        ) ELSE (
            SET "JTEST_HOME=%~2"
            SHIFT
        )
        GOTO :next_arg
    )
    IF /I "%~1"=="codex-cli"    SET "AGENTS_TO_INSTALL=!AGENTS_TO_INSTALL! codex-cli"   & GOTO :next_arg
    IF /I "%~1"=="copilot-cli"  SET "AGENTS_TO_INSTALL=!AGENTS_TO_INSTALL! copilot-cli" & GOTO :next_arg
    echo Error: Unknown argument: '%~1' 1>&2
    echo        Supported agents: %SUPPORTED_AGENTS% 1>&2
    SET "overall_exit=1"
:next_arg
    SHIFT
    GOTO :arg_loop
:end_arg_loop

IF %overall_exit% NEQ 0 EXIT /B %overall_exit%
IF NOT DEFINED AGENTS_TO_INSTALL EXIT /B 0

REM ── Validate JTEST_HOME ───────────────────────────────────────────────────
IF NOT DEFINED JTEST_HOME (
    echo Error: JTEST_HOME is not set. 1>&2
    echo        Provide it via --jtest.home ^<path^> or set the JTEST_HOME environment variable. 1>&2
    EXIT /B 1
)

CALL :check_prerequisites
IF ERRORLEVEL 1 EXIT /B 1

FOR %%A IN (%AGENTS_TO_INSTALL%) DO (
    echo.
    IF /I "%%A"=="copilot-cli" CALL :install_copilot_cli
    IF /I "%%A"=="codex-cli"   CALL :install_codex_cli
)

EXIT /B %overall_exit%

REM ════════════════════════════════════════════════════════════════════════════
REM  FUNCTIONS
REM ════════════════════════════════════════════════════════════════════════════

:usage
echo Usage: %SCRIPT_NAME% [--jtest.home ^<path^>] ^<coding-agent^> [^<coding-agent2^> ...]
echo.
echo Installs Parasoft Jtest MCP tools, Parasoft AI skills and AI agents for the specified coding agent^(s^).
echo.
echo   MCP tools source : %%JTEST_HOME%%\integration\mcp\jtestmcp.bat
echo   AI skills source : %AI_HOME%\skills
echo   AI agents source : %AI_HOME%\agents
echo.
echo Options:
echo   --jtest.home ^<path^>   Path to the Jtest installation directory.
echo                          Can also be set via the JTEST_HOME environment variable.
echo.
echo Supported coding agents:
echo   codex-cli      OpenAI Codex CLI
echo   copilot-cli    GitHub Copilot CLI
echo.
echo Examples:
echo   %SCRIPT_NAME% --jtest.home "C:\Jtest\2025.1" copilot-cli
echo   %SCRIPT_NAME% --jtest.home "C:\Jtest\2025.1" codex-cli copilot-cli
echo   %SCRIPT_NAME% copilot-cli                    ^(requires JTEST_HOME env var^)
echo.
echo Note:
echo   JTEST_HOME must be provided via --jtest.home or the JTEST_HOME environment variable.
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────

:check_prerequisites
IF NOT EXIST "%JTEST_HOME%\integration\mcp\jtestmcp.bat" (
    echo Error: MCP launcher not found: %JTEST_HOME%\integration\mcp\jtestmcp.bat 1>&2
    EXIT /B 1
)
IF NOT EXIST "%AI_HOME%\skills\" (
    echo Error: Skills directory not found: %AI_HOME%\skills 1>&2
    EXIT /B 1
)
IF NOT EXIST "%AI_HOME%\agents\" (
    echo Error: Agents directory not found: %AI_HOME%\agents 1>&2
    EXIT /B 1
)
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────
REM :copy_skills <target-dir>

:copy_skills
SET "copy_src=%AI_HOME%\skills"
SET "copy_dst=%~1"
IF NOT EXIST "%copy_src%\" EXIT /B 0
echo   Copying skills from %copy_src% to %copy_dst% ...
IF NOT EXIST "%copy_dst%\" MKDIR "%copy_dst%"
ROBOCOPY "%copy_src%" "%copy_dst%" /E /NJH /NJS /NS /NC /NP >nul 2>&1
IF ERRORLEVEL 8 (
    echo   Error: Failed to copy skills from %copy_src% 1>&2
    EXIT /B 1
)
echo   Skills installed.
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────
REM :copy_agent <agent-file-name> <target-dir>

:copy_agent
SET "agent_src=%AI_HOME%\agents\%~1"
SET "agent_dst=%~2"
IF NOT EXIST "%agent_src%" EXIT /B 0
echo   Copying agent %~1 to %agent_dst% ...
IF NOT EXIST "%agent_dst%\" MKDIR "%agent_dst%"
COPY /Y "%agent_src%" "%agent_dst%\" >nul 2>&1
IF ERRORLEVEL 1 (
    echo   Error: Failed to copy agent %~1 1>&2
    EXIT /B 1
)
echo   Agent installed.
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────
REM :install_copilot_cli

:install_copilot_cli
echo ^>^>^> Installing Parasoft Jtest integration for GitHub Copilot CLI ...
SET "mcp_cmd=%JTEST_HOME%\integration\mcp\jtestmcp.bat"
SET "_rc=0"
WHERE copilot >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    CALL copilot mcp get "%MCP_SERVER_NAME%" >nul 2>&1
    IF !ERRORLEVEL! EQU 0 (
        echo   Warning: MCP server '%MCP_SERVER_NAME%' is already registered. 1>&2
        echo   It is advisable to remove it first with: 1>&2
        echo     copilot mcp remove %MCP_SERVER_NAME% 1>&2
    ) ELSE (
        CALL copilot mcp add --transport stdio "%MCP_SERVER_NAME%" "%mcp_cmd%"
        IF ERRORLEVEL 1 (
            echo   Error: Failed to register MCP server via Copilot CLI. 1>&2
            SET "_rc=1"
        ) ELSE (
            echo   Registered MCP server '%MCP_SERVER_NAME%' via Copilot CLI.
        )
    )
) ELSE (
    echo   Warning: 'copilot' CLI not found -- cannot register MCP server automatically. 1>&2
    echo   Run the following command manually after installing the Copilot CLI: 1>&2
    echo     copilot mcp add --transport stdio %MCP_SERVER_NAME% "%mcp_cmd%" 1>&2
)
CALL :copy_skills "%USERPROFILE%\.copilot\skills"
IF ERRORLEVEL 1 EXIT /B 1
CALL :copy_agent "jtest-fix-violation.md" "%USERPROFILE%\.copilot\agents"
IF ERRORLEVEL 1 EXIT /B 1
echo ^>^>^> GitHub Copilot CLI integration installed.
EXIT /B !_rc!

REM ─────────────────────────────────────────────────────────────────────────────
REM :install_codex_cli

:install_codex_cli
echo ^>^>^> Installing Parasoft Jtest integration for Codex CLI ...
SET "mcp_cmd=%JTEST_HOME%\integration\mcp\jtestmcp.bat"
SET "_rc=0"
WHERE codex >nul 2>&1
IF %ERRORLEVEL% EQU 0 (
    CALL codex mcp add %MCP_SERVER_NAME% -- "%mcp_cmd%"
    IF ERRORLEVEL 1 (
        echo   Error: Failed to register MCP server via Codex CLI. 1>&2
        SET "_rc=1"
    ) ELSE (
        echo   Registered MCP server '%MCP_SERVER_NAME%' via Codex CLI.
    )
) ELSE (
    echo   Warning: 'codex' CLI not found -- cannot register MCP server automatically. 1>&2
    echo   Run the following command manually after installing the Codex CLI: 1>&2
    echo     codex mcp add %MCP_SERVER_NAME% -- "%mcp_cmd%" 1>&2
)
CALL :copy_skills "%USERPROFILE%\.codex\skills"
IF ERRORLEVEL 1 EXIT /B 1
CALL :copy_agent "jtest-fix-violation.toml" "%USERPROFILE%\.codex\agents"
IF ERRORLEVEL 1 EXIT /B 1
echo ^>^>^> Codex CLI integration installed.
EXIT /B !_rc!
