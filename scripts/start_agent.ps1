## TODO [am] PS script should be refactored like .bat and .sh scripts if we are going to support separate scripts for PowerShell
#============================
# This script is used to start the Copilot agent with specific allowed paths and tools. 
# It checks for the ANALYZED_PROJECT_PATH environment variable and sets the current location accordingly. 
# If the ANALYZED_PROJECT_PATH environment variable is not set, it will launch the Copilot agent in the current directory.
# The command to be executed is built from the allowed paths and tools defined in the script.

# Define an array of allowed paths
$AllowedPaths = @(
    $env:ANALYZED_PROJECT_PATH
    "$env:JTEST_HOME\integration\ai\skills\"
    "$env:JTEST_HOME"
)

# Define an array of allowed tools
$AllowedTools = @(
    "shell"
    "view"
    "create"
    "edit"
    "write"
    "read"
    "grep"
    "glob"
    "memory"
)

# Define an array of denied tools
$DeniedTools = @(
#    "shell(git push)"
)

$SCRIPT_NAME = Split-Path -Leaf $PSCommandPath
$SUPPORTED_AGENTS = @(
    "copilot"
)

function help {
Write-Host @"
Usage: $SCRIPT_NAME <agent-command> [additional-args]"
Example: $SCRIPT_NAME copilot --some-flag"

Run the specified agent command with preconfigured allowed paths and tools.
The allowed paths could be set in ALLOWED_PATHS array in this script or via --add-dir option.
The allowed and denied tools could be set in ALLOWED_TOOLS and DENIED_TOOLS arrays.

Supported coding agents:
  copilot    GitHub Copilot CLI

Examples:
  $SCRIPT_NAME copilot
  $SCRIPT_NAME copilot --add-dir /path/to/another/allowed/dir

Note:
  The ANALYZED_PROJECT_PATH environment variable can be set to specify the main project directory for the Copilot agent.
  If not set, the agent will be launched in the current directory.
"@
}


function prepare_copilot_cmd {
    # Build the arguments array for allowed paths
    $AllowedPathsCmd = @()

    if ([string]::IsNullOrWhiteSpace($env:ANALYZED_PROJECT_PATH)) {
        Write-Warning "ANALYZED_PROJECT_PATH environment variable is not set. Copilot agent will be launched in current directory: $PWD"
        $AllowedPathsCmd += "--add-dir"
        $AllowedPathsCmd += "$PWD"
    } else {
        Set-Location $env:ANALYZED_PROJECT_PATH
    }

    foreach ($p in $AllowedPaths) {
        if (-not [string]::IsNullOrWhiteSpace($p)) {
            $AllowedPathsCmd += "--add-dir"
            $AllowedPathsCmd += "$p"
        }
    }

    # Join tools into comma-separated strings
    $AllowedToolsCmd = $AllowedTools -join ", "
    $DeniedToolsCmd  = $DeniedTools  -join ", "

    $ResultedCommand = @()
    $ResultedCommand += $AllowedPathsCmd
    if ($AllowedToolsCmd.Count -gt 0) {
            $ResultedCommand += "--allow-tool"
            $ResultedCommand += $AllowedToolsCmd
    }
    if ($DeniedToolsCmd.Count -gt 0) {
            $ResultedCommand += "--deny-tool"
            $ResultedCommand += $DeniedToolsCmd
    }
    return $ResultedCommand
}

#=============================== main =================================

$cmd = $args[0]
if (-not $cmd) {
    help
    exit 0
}
if ($args.Count -gt 1) {
    $additionalArgs = $args[1..($args.Count - 1)]
} else {
    $additionalArgs = @()
}

switch ($cmd) {

    { $_ -in @("-h", "--help", "-H", "--HELP") } {
        help
        break
    }

    "copilot" {
        $agentCommand = "copilot.exe"
        $ResultedCommand = prepare_copilot_cmd
        Write-Host ($agentCommand + " " + ($ResultedCommand -join ' ') + " " + ($additionalArgs -join ' '))
        & $agentCommand @ResultedCommand @additionalArgs
        break
    }

    default {
        Write-Error "Error: Unknown coding agent: '$cmd'"
        Write-Error "       Supported agents: $SUPPORTED_AGENTS"
        exit 1
    }
}

