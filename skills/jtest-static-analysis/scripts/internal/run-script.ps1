# =============================================================================
# run-script.ps1  —  OS-dispatch helper: invoke a named script from JTEST_STATIC_SCRIPT_DIR
#
# Usage:
#   & "$env:JTEST_STATIC_SCRIPT_DIR\internal\run-script.ps1" -ScriptName <name>
#
# Parameters:
#   -ScriptName — script name: "build-verify" or "jtest-analyze"
#
# Requires:
#   $env:JTEST_STATIC_SCRIPT_DIR — set by resolve-config.ps1 before this helper is called
#
# Behaviour:
#   Prefers <JTEST_STATIC_SCRIPT_DIR>\<name>\<name>.bat; falls back to .ps1.
#   Propagates the script's exit code to the caller unchanged.
#
# Exit codes:
#   As returned by the invoked script.
#   1 — script name missing, JTEST_STATIC_SCRIPT_DIR not set, or script file not found.
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ScriptName
)

if (-not $env:JTEST_STATIC_SCRIPT_DIR -or $env:JTEST_STATIC_SCRIPT_DIR -eq "") {
    Write-Error "ERROR: [run-script] JTEST_STATIC_SCRIPT_DIR is not set. Run resolve-config first."
    exit 1
}

$batFile = Join-Path $env:JTEST_STATIC_SCRIPT_DIR "$ScriptName\$ScriptName.bat"
$ps1File = Join-Path $env:JTEST_STATIC_SCRIPT_DIR "$ScriptName\$ScriptName.ps1"

if (Test-Path $batFile -PathType Leaf) {
    Write-Host "[run-script] $ScriptName"
    cmd /c "`"$batFile`""
    exit $LASTEXITCODE
}

if (Test-Path $ps1File -PathType Leaf) {
    Write-Host "[run-script] $ScriptName"
    & powershell -ExecutionPolicy Bypass -File $ps1File
    exit $LASTEXITCODE
}

Write-Error "ERROR: [run-script] Script not found: $batFile (or .ps1)"
exit 1

