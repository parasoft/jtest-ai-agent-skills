@echo off
setlocal EnableExtensions EnableDelayedExpansion

SET "SCRIPT_NAME=%~nx0"
SET "MCP_SERVER_NAME=jtestmcp"
SET "SUPPORTED_AGENTS=codex-cli, copilot-cli"

REM ── Derive AI_HOME (parent of the scripts folder) from script location ────
FOR %%I IN ("%~dp0..") DO SET "AI_HOME=%%~fI"

REM Detect Python interpreter (try 'python' then Windows 'py' launcher)
SET "PYTHON_EXE="
python --version >nul 2>&1 && SET "PYTHON_EXE=python"
IF NOT DEFINED PYTHON_EXE (
    py --version >nul 2>&1 && SET "PYTHON_EXE=py"
)

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
IF NOT DEFINED PYTHON_EXE (
    echo   Warning: Python 3 not found. MCP configuration files will NOT be modified. 1>&2
    echo   Install Python 3 from https://python.org and re-run to apply changes automatically. 1>&2
)
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
SET "cfg_file=%USERPROFILE%\.copilot\mcp-config.json"
SET "mcp_cmd=%JTEST_HOME%\integration\mcp\jtestmcp.bat"
SET "mcp_j=%mcp_cmd:\=\\%"
IF DEFINED PYTHON_EXE (
    CALL :run_merge_python json-local "%cfg_file%" "%MCP_SERVER_NAME%" "%mcp_cmd%"
    IF ERRORLEVEL 1 EXIT /B 1
) ELSE (
    IF EXIST "%cfg_file%" (
        echo   Python not found. Add the following entry to %cfg_file%
        echo   under the "mcpServers" key:
        echo.
        echo     "%MCP_SERVER_NAME%": {
        echo       "type": "local",
        echo       "command": "%mcp_j%",
        echo       "tools": ["*"],
        echo       "args": []
        echo     }
        echo.
    ) ELSE (
        IF NOT EXIST "%USERPROFILE%\.copilot\" MKDIR "%USERPROFILE%\.copilot"
        (
            echo {
            echo   "mcpServers": {
            echo     "%MCP_SERVER_NAME%": {
            echo       "type": "local",
            echo       "command": "%mcp_j%",
            echo       "tools": [
            echo         "*"
            echo       ],
            echo       "args": []
            echo     }
            echo   }
            echo }
        ) > "%cfg_file%"
        echo   Written MCP configuration to %cfg_file%
    )
)
CALL :copy_skills "%USERPROFILE%\.copilot\skills"
CALL :copy_agent "jtest-fix-violation.md" "%USERPROFILE%\.copilot\agents"
echo ^>^>^> GitHub Copilot CLI integration installed.
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────
REM :install_codex_cli

:install_codex_cli
echo ^>^>^> Installing Parasoft Jtest integration for Codex CLI ...
SET "cfg_file=%USERPROFILE%\.codex\config.toml"
SET "mcp_cmd=%JTEST_HOME%\integration\mcp\jtestmcp.bat"
SET "mcp_j=%mcp_cmd:\=\\%"
IF DEFINED PYTHON_EXE (
    CALL :run_merge_python toml "%cfg_file%" "%MCP_SERVER_NAME%" "%mcp_cmd%"
    IF ERRORLEVEL 1 EXIT /B 1
) ELSE (
    IF EXIST "%cfg_file%" (
        echo   Python not found. Add or update the following in %cfg_file%:
        echo.
        echo   [mcp_servers.%MCP_SERVER_NAME%]
        echo   command = "%mcp_j%"
        echo.
    ) ELSE (
        IF NOT EXIST "%USERPROFILE%\.codex\" MKDIR "%USERPROFILE%\.codex"
        (
            echo [mcp_servers.%MCP_SERVER_NAME%]
            echo command = "%mcp_j%"
        ) > "%cfg_file%"
        echo   Written MCP configuration to %cfg_file%
    )
)
CALL :copy_skills "%USERPROFILE%\.codex\skills"
CALL :copy_agent "jtest-fix-violation.toml" "%USERPROFILE%\.codex\agents"
echo ^>^>^> Codex CLI integration installed.
EXIT /B 0

REM ─────────────────────────────────────────────────────────────────────────────
REM :run_merge_python <fmt> <cfg_file> <server_name> <mcp_cmd>
REM   Locates the embedded Python script in this batch file (everything after the
REM   __PYTHON_SCRIPT_START__ marker) and runs it in a temp file.

:run_merge_python
SETLOCAL
SET "_pystart=0"
FOR /F "tokens=1 delims=:" %%L IN ('findstr /n /c:"__PYTHON_SCRIPT_START__" "%~f0"') DO SET "_pystart=%%L"
IF "%_pystart%"=="0" (
    echo   Error: could not locate embedded Python script 1>&2
    ENDLOCAL & EXIT /B 1
)
SET "TMPPY=%TEMP%\merge_mcp_%RANDOM%.py"
more +%_pystart% "%~f0" > "%TMPPY%"
%PYTHON_EXE% "%TMPPY%" %1 %2 %3 %4
SET "_exitcode=%ERRORLEVEL%"
DEL /Q "%TMPPY%" >nul 2>&1
ENDLOCAL & EXIT /B %_exitcode%

REM __PYTHON_SCRIPT_START__
#!/usr/bin/env python3
"""
merge_mcp_config -- Merge a Jtest MCP server entry into an AI coding-agent config file.

Usage:
    merge_mcp_config.py json-local  <config_file> <server_name> <mcp_cmd>
    merge_mcp_config.py json        <config_file> <server_name> <mcp_cmd>
    merge_mcp_config.py toml        <config_file> <server_name> <mcp_cmd>

Formats:
    json-local  JSON with type=local and tools=[*]  -- GitHub Copilot CLI
    toml        TOML [mcp_servers.<name>] section   -- Codex CLI
"""

import sys
import os
import json


def _load_json(path):
    if not os.path.exists(path):
        return {}
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"  Warning: could not parse {path} ({exc}) -- starting fresh.", file=sys.stderr)
        return {}


def merge_json(config_file, server_name, entry):
    cfg = _load_json(config_file)
    if not isinstance(cfg.get('mcpServers'), dict):
        cfg['mcpServers'] = {}
    existed = server_name in cfg['mcpServers']
    cfg['mcpServers'][server_name] = entry
    os.makedirs(os.path.dirname(os.path.abspath(config_file)), exist_ok=True)
    with open(config_file, 'w', encoding='utf-8') as f:
        json.dump(cfg, f, indent=2)
        f.write('\n')
    print(f"  {'Updated' if existed else 'Added'} MCP entry in {config_file}")


def merge_toml(config_file, server_name, mcp_cmd):
    escaped_cmd = mcp_cmd.replace('\\', '\\\\')
    section = f"[mcp_servers.{server_name}]"
    if os.path.exists(config_file):
        with open(config_file, encoding='utf-8') as f:
            lines = f.readlines()
        found = False
        i = 0
        while i < len(lines):
            if lines[i].strip() == section:
                found = True
                i += 1
                # Remove existing key-value pairs until next section or EOF
                while i < len(lines) and not lines[i].strip().startswith('['):
                    lines.pop(i)
                # Insert new command
                lines.insert(i, f'command = "{escaped_cmd}"\n')
                break
            i += 1
        if found:
            with open(config_file, 'w', encoding='utf-8') as f:
                f.writelines(lines)
            print(f"  Updated MCP entry in {config_file}")
        else:
            with open(config_file, 'a', encoding='utf-8') as f:
                f.write(f"\n{section}\ncommand = \"{escaped_cmd}\"\n")
            print(f"  Appended MCP entry to {config_file}")
    else:
        os.makedirs(os.path.dirname(os.path.abspath(config_file)), exist_ok=True)
        with open(config_file, 'w', encoding='utf-8') as f:
            f.write(f"{section}\ncommand = \"{escaped_cmd}\"\n")
        print(f"  Written MCP configuration to {config_file}")


def main():
    if len(sys.argv) != 5:
        print(__doc__)
        sys.exit(1)
    fmt, cfg, name, cmd = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
    if fmt == 'json-local':
        merge_json(cfg, name, {"type": "local", "command": cmd, "tools": ["*"], "args": []})
    elif fmt == 'json':
        merge_json(cfg, name, {"command": cmd, "args": []})
    elif fmt == 'toml':
        merge_toml(cfg, name, cmd)
    else:
        print(f"Error: unknown format '{fmt}'. Use json-local, json, or toml.", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
