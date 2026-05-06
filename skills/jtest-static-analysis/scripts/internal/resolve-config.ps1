# =============================================================================
# resolve-config.ps1  —  Load, parse, and validate all Jtest Static Analysis settings
#
# This script is dot-sourced by the skill runner or other scripts.
# After sourcing, all resolved variables are set as environment variables
# in the calling session.
#
# Usage:
#   . "$PSScriptRoot\internal\resolve-config.ps1" -SkillDir "<skill_dir>"
#
# Parameters:
#   -SkillDir  — absolute path to the skill root directory (contains SKILL.md)
#
# On validation failure the script writes an ERROR message to stderr and
# exits with code 1.
#
# Environment variables set on success:
#   JTEST_HOME, ANALYZED_PROJECT_PATH, JTEST_STATIC_CONFIGURATION, JTEST_COMMIT_FIXES,
#   JTEST_STATIC_FILTER_RULE, JTEST_SETTINGS, JTEST_STATIC_BASE_REPORT, JTEST_STATIC_BASE_COVERAGE,
#   JTEST_REFERENCE_BRANCH, GIT_WORKSPACE, GIT_BRANCH,
#   JTEST_STATIC_SCRIPT_DIR, JTEST_RESOURCE
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$SkillDir
)

$ErrorActionPreference = "Stop"

function Die($msg) {
    Write-Error "ERROR: $msg"
    exit 1
}

function SetIfUnset([string]$Name, [string]$Value) {
    $current = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not $current -or $current -eq "") {
        [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
    }
}

# =============================================================================
# Step 0: Load optional config file
# =============================================================================
$recognizedKeys = @(
    "JTEST_HOME", "ANALYZED_PROJECT_PATH", "JTEST_STATIC_CONFIGURATION",
    "JTEST_COMMIT_FIXES", "JTEST_STATIC_FILTER_RULE", "JTEST_SETTINGS",
    "JTEST_STATIC_BASE_REPORT", "JTEST_STATIC_BASE_COVERAGE",
    "JTEST_STATIC_NO_OF_MAX_FIXES", "JTEST_STATIC_SCRIPT_DIR", "JTEST_REFERENCE_BRANCH"
)

$configPath = $env:JTEST_SKILLS_CONFIG
if ($configPath -and $configPath -ne "") {
    if (-not (Test-Path $configPath -PathType Leaf)) {
        Die "JTEST_SKILLS_CONFIG points to a file that does not exist: $configPath. Verify the path and retry."
    }
    foreach ($line in Get-Content $configPath) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
        $eqIdx = $trimmed.IndexOf("=")
        if ($eqIdx -lt 1) { continue }
        $key = $trimmed.Substring(0, $eqIdx).Trim()
        $val = $trimmed.Substring($eqIdx + 1).Trim()
        if ($recognizedKeys -contains $key) {
            SetIfUnset $key $val
        }
    }
}

# =============================================================================
# Step 1: Resolve required & optional settings
# =============================================================================

# ---- JTEST_HOME -------------------------------------------------------------
if (-not $env:JTEST_HOME -or $env:JTEST_HOME -eq "") {
    $jtestCmd = Get-Command "jtestcli.exe" -ErrorAction SilentlyContinue
    if (-not $jtestCmd) {
        $jtestCmd = Get-Command "jtestcli" -ErrorAction SilentlyContinue
    }
    if ($jtestCmd) {
        $env:JTEST_HOME = Split-Path $jtestCmd.Source -Parent
    } else {
        Die "JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry."
    }
}

# ---- ANALYZED_PROJECT_PATH -----------------------------------------------------------
if (-not $env:ANALYZED_PROJECT_PATH -or $env:ANALYZED_PROJECT_PATH -eq "" -or -not (Test-Path $env:ANALYZED_PROJECT_PATH -PathType Container)) {
    Die "ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry."
}

# ---- JTEST_STATIC_CONFIGURATION -----------------------------------------------
if (-not $env:JTEST_STATIC_CONFIGURATION -or $env:JTEST_STATIC_CONFIGURATION -eq "") {
    $env:JTEST_STATIC_CONFIGURATION = "builtin://Recommended Rules"
}

# ---- JTEST_COMMIT_FIXES -----------------------------------------------------
if (-not $env:JTEST_COMMIT_FIXES -or $env:JTEST_COMMIT_FIXES -eq "") {
    $env:JTEST_COMMIT_FIXES = "false"
}

# ---- JTEST_STATIC_FILTER_RULE (optional) -------------------------------------------
if (-not $env:JTEST_STATIC_FILTER_RULE) { $env:JTEST_STATIC_FILTER_RULE = "" }

# ---- JTEST_SETTINGS ---------------------------------------------------------
if ($env:JTEST_SETTINGS -and $env:JTEST_SETTINGS -ne "") {
    if (-not (Test-Path $env:JTEST_SETTINGS -PathType Leaf)) {
        Die "JTEST_SETTINGS points to a file that does not exist: $($env:JTEST_SETTINGS). Verify the path and retry."
    }
} else {
    $env:JTEST_SETTINGS = ""
}

# ---- JTEST_STATIC_BASE_REPORT ------------------------------------------------------
if ($env:JTEST_STATIC_BASE_REPORT -and $env:JTEST_STATIC_BASE_REPORT -ne "") {
    if (-not (Test-Path $env:JTEST_STATIC_BASE_REPORT -PathType Leaf)) {
        Die "JTEST_STATIC_BASE_REPORT points to a file that does not exist: $($env:JTEST_STATIC_BASE_REPORT). Verify the path and retry."
    }
} else {
    $env:JTEST_STATIC_BASE_REPORT = ""
}

# ---- JTEST_STATIC_BASE_COVERAGE ----------------------------------------------------
if ($env:JTEST_STATIC_BASE_COVERAGE -and $env:JTEST_STATIC_BASE_COVERAGE -ne "") {
    if (-not (Test-Path $env:JTEST_STATIC_BASE_COVERAGE -PathType Leaf)) {
        Die "JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: $($env:JTEST_STATIC_BASE_COVERAGE). Verify the path and retry."
    }
} else {
    $env:JTEST_STATIC_BASE_COVERAGE = ""
}

# ---- JTEST_STATIC_NO_OF_MAX_FIXES --------------------------------------------------
if (-not $env:JTEST_STATIC_NO_OF_MAX_FIXES -or $env:JTEST_STATIC_NO_OF_MAX_FIXES -eq "") {
    $env:JTEST_STATIC_NO_OF_MAX_FIXES = "10"
}

# ---- JTEST_STATIC_SCRIPT_DIR --------------------------------------------------------------
$scriptDirSource = "(default)"
if (-not $env:JTEST_STATIC_SCRIPT_DIR -or $env:JTEST_STATIC_SCRIPT_DIR -eq "") {
    $env:JTEST_STATIC_SCRIPT_DIR = Join-Path $SkillDir "scripts"
} else {
    $scriptDirSource = "(override)"
}

if (-not (Test-Path $env:JTEST_STATIC_SCRIPT_DIR -PathType Container)) {
    Die "JTEST_STATIC_SCRIPT_DIR points to a directory that does not exist: $($env:JTEST_STATIC_SCRIPT_DIR). Verify the path and retry."
}

# Validate required scripts exist (prefer .bat, then .ps1)
$buildVerifyOk = (Test-Path (Join-Path $env:JTEST_STATIC_SCRIPT_DIR "build-verify\build-verify.bat")) -or `
                 (Test-Path (Join-Path $env:JTEST_STATIC_SCRIPT_DIR "build-verify\build-verify.ps1"))
if (-not $buildVerifyOk) {
    Die "JTEST_STATIC_SCRIPT_DIR=$($env:JTEST_STATIC_SCRIPT_DIR) is missing required script build-verify.bat (or .ps1). Provide both build-verify and jtest-analyze scripts and retry."
}

$jtestAnalyzeOk = (Test-Path (Join-Path $env:JTEST_STATIC_SCRIPT_DIR "jtest-analyze\jtest-analyze.bat")) -or `
                  (Test-Path (Join-Path $env:JTEST_STATIC_SCRIPT_DIR "jtest-analyze\jtest-analyze.ps1"))
if (-not $jtestAnalyzeOk) {
    Die "JTEST_STATIC_SCRIPT_DIR=$($env:JTEST_STATIC_SCRIPT_DIR) is missing required script jtest-analyze.bat (or .ps1). Provide both build-verify and jtest-analyze scripts and retry."
}

# ---- JTEST_REFERENCE_BRANCH (optional) -----------------------------------------
if (-not $env:JTEST_REFERENCE_BRANCH) { $env:JTEST_REFERENCE_BRANCH = "" }

# Ensure git context variables do not carry stale values between runs
$env:GIT_BRANCH = ""
$env:GIT_WORKSPACE = ""

# Resolve git context and validate target branch when JTEST_REFERENCE_BRANCH is set
if ($env:JTEST_REFERENCE_BRANCH -and $env:JTEST_REFERENCE_BRANCH -ne "") {
    $solutionDir = $env:ANALYZED_PROJECT_PATH
    $gitCmd = Get-Command "git" -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        Die "JTEST_REFERENCE_BRANCH is set, but git is not available on PATH. Install git or unset JTEST_REFERENCE_BRANCH."
    }

    & git -C $solutionDir rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        Die "JTEST_REFERENCE_BRANCH is set, but the solution directory is not inside a git repository: $solutionDir"
    }

    $gitWorkspace = (& git -C $solutionDir rev-parse --show-toplevel).Trim()
    if (-not $gitWorkspace -or $LASTEXITCODE -ne 0) {
        Die "Failed to determine git workspace for solution directory: $solutionDir"
    }

    $gitBranch = (& git -C $solutionDir rev-parse --abbrev-ref HEAD).Trim()
    if (-not $gitBranch -or $LASTEXITCODE -ne 0) {
        Die "Failed to determine current git branch for solution directory: $solutionDir"
    }

    $target = $env:JTEST_REFERENCE_BRANCH
    & git -C $solutionDir show-ref --verify --quiet "refs/heads/$target"
    $hasLocalTarget = ($LASTEXITCODE -eq 0)
    $remoteTargetRefs = & git -C $solutionDir for-each-ref --format="%(refname)" "refs/remotes/*/$target"
    $hasRemoteTarget = ($LASTEXITCODE -eq 0) -and $remoteTargetRefs -and $remoteTargetRefs.Count -gt 0

    if (-not $hasLocalTarget -and -not $hasRemoteTarget) {
        Die "JTEST_REFERENCE_BRANCH '$target' does not exist in the repository."
    }

    $env:GIT_WORKSPACE = $gitWorkspace
    $env:GIT_BRANCH = $gitBranch
}

# ---- JTEST_RESOURCE (set by the skill before calling; default to empty) ------
if (-not $env:JTEST_RESOURCE) { $env:JTEST_RESOURCE = "" }

# =============================================================================
# Step 2: Verify Jtest installation
# =============================================================================
$jtestExe = Join-Path $env:JTEST_HOME "jtestcli.exe"
$jtestBin = Join-Path $env:JTEST_HOME "jtestcli"
if (-not (Test-Path $jtestExe) -and -not (Test-Path $jtestBin)) {
    Die "jtestcli not found in JTEST_HOME=$($env:JTEST_HOME). Verify the Jtest installation path."
}

# =============================================================================
# Print resolved configuration
# =============================================================================
$configDisplay = if ($env:JTEST_SKILLS_CONFIG -and $env:JTEST_SKILLS_CONFIG -ne "") { $env:JTEST_SKILLS_CONFIG } else { "(not set)" }
$filterDisplay = if ($env:JTEST_STATIC_FILTER_RULE -and $env:JTEST_STATIC_FILTER_RULE -ne "") { $env:JTEST_STATIC_FILTER_RULE } else { "(not set)" }
$settingsDisplay = if ($env:JTEST_SETTINGS -and $env:JTEST_SETTINGS -ne "") { $env:JTEST_SETTINGS } else { "(not set)" }
$baseReportDisplay = if ($env:JTEST_STATIC_BASE_REPORT -and $env:JTEST_STATIC_BASE_REPORT -ne "") { $env:JTEST_STATIC_BASE_REPORT } else { "(not set)" }
$baseCoverageDisplay = if ($env:JTEST_STATIC_BASE_COVERAGE -and $env:JTEST_STATIC_BASE_COVERAGE -ne "") { $env:JTEST_STATIC_BASE_COVERAGE } else { "(not set)" }
$scopeDisplay = if ($env:JTEST_RESOURCE -and $env:JTEST_RESOURCE -ne "") { $env:JTEST_RESOURCE } else { "(none - full project)" }
$targetBranchDisplay = if ($env:JTEST_REFERENCE_BRANCH -and $env:JTEST_REFERENCE_BRANCH -ne "") { $env:JTEST_REFERENCE_BRANCH } else { "(not set)" }

$resolvedConfigContent = @"
Resolved configuration:
  JTEST_SKILLS_CONFIG    = $configDisplay
  JTEST_HOME               = $($env:JTEST_HOME)
  ANALYZED_PROJECT_PATH             = $($env:ANALYZED_PROJECT_PATH)
  JTEST_STATIC_CONFIGURATION = $($env:JTEST_STATIC_CONFIGURATION)
  JTEST_COMMIT_FIXES       = $($env:JTEST_COMMIT_FIXES)
  JTEST_STATIC_FILTER_RULE        = $filterDisplay
  JTEST_SETTINGS           = $settingsDisplay
  JTEST_STATIC_BASE_REPORT        = $baseReportDisplay
  JTEST_STATIC_BASE_COVERAGE      = $baseCoverageDisplay
  JTEST_STATIC_NO_OF_MAX_FIXES    = $($env:JTEST_STATIC_NO_OF_MAX_FIXES)
  JTEST_REFERENCE_BRANCH      = $targetBranchDisplay
  JTEST_STATIC_SCRIPT_DIR               = $($env:JTEST_STATIC_SCRIPT_DIR) $scriptDirSource
  ANALYSIS_SCOPE           = $scopeDisplay
"@

Write-Host $resolvedConfigContent
$resolvedConfigContent | Out-File -FilePath (Join-Path $PWD "resolved.config") -Encoding utf8

