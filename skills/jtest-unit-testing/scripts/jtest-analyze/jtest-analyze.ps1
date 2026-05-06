# =============================================================================
# jtest-analyze.ps1  —  Template for running UTA tests creation
#
# Called by the UTA Test Creation skill (always, via SCRIPT_DIR).
#
# Environment variables provided by the skill (always set before this script
# is invoked):
#   JTEST_HOME               – Jtest installation directory
#   ANALYZED_PROJECT_PATH    – Absolute path to the project root
#   JTEST_UTA_CONFIGURATION  – Jtest test configuration name
#   JTEST_SETTINGS           – Absolute path to Jtest settings file (may be empty)
#   JTEST_UTA_RESOURCE       - Pattern to narrow down the scope to test
#   JTEST_REFERENCE_BRANCH      – When set, restricts analysis scope to changes
#                              relative to the specified target branch (git).
#                              GIT_WORKSPACE and GIT_BRANCH must also be set
#                              (resolved automatically by resolve-config).
#
# Exit codes:
#   0  – Analysis completed successfully; report.xml produced
#   1  – Analysis failed
#
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "[jtest-analyze] ANALYZED_PROJECT_PATH = $env:ANALYZED_PROJECT_PATH"
Write-Host "[jtest-analyze] JTEST_HOME   = $env:JTEST_HOME"

Set-Location -Path $env:ANALYZED_PROJECT_PATH

# ---------------------------------------------------------------------------
# Build the -Djtest.settings argument (omit when JTEST_SETTINGS is empty)
# ---------------------------------------------------------------------------
$settingsArg = @()
if ($env:JTEST_SETTINGS -and $env:JTEST_SETTINGS -ne "") {
    $settingsArg = @("-Djtest.settings=`"$($env:JTEST_SETTINGS)`"")
}

# ---------------------------------------------------------------------------
# Build the -Djtest.resources argument (omit when JTEST_UTA_RESOURCE is empty)
# ---------------------------------------------------------------------------
$scopeToTestArg = @()
if ($env:JTEST_UTA_RESOURCE -and $env:JTEST_UTA_RESOURCE -ne "") {
    $scopeToTestArg = @("-Djtest.resources=`"$($env:JTEST_UTA_RESOURCE)`"")
}

# ---------------------------------------------------------------------------
# Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
# ---------------------------------------------------------------------------
$branchArgs = @()
if ($env:JTEST_REFERENCE_BRANCH -and $env:JTEST_REFERENCE_BRANCH -ne "") {
    $branchArgs += "-Dproperty.scope.scontrol=true"
    $branchArgs += "-Dproperty.scope.scontrol.files.filter.mode=branch"
    $branchArgs += "-Dproperty.scope.scontrol.lines.filter.mode=branch"
    $branchArgs += "-Dproperty.scontrol.rep1.type=git"
    $branchArgs += "-Dproperty.scontrol.rep1.git.workspace=$($env:GIT_WORKSPACE)"
    $branchArgs += "-Dproperty.scontrol.rep1.git.branch=$($env:GIT_BRANCH)"
    $branchArgs += "-Dproperty.scope.scontrol.ref.branch=$($env:JTEST_REFERENCE_BRANCH)"
}

# ---------------------------------------------------------------------------
# Detect build wrapper / fall back to system tool
# ---------------------------------------------------------------------------
$buildCmd  = $null
$buildType = $null

if (Test-Path "mvnw.cmd") {
    $buildCmd  = ".\mvnw.cmd"
    $buildType = "maven"
} elseif (Test-Path "gradlew.bat") {
    $buildCmd  = ".\gradlew.bat"
    $buildType = "gradle"
} else {
    if (Get-Command "mvn" -ErrorAction SilentlyContinue) {
        $buildCmd  = "mvn"
        $buildType = "maven"
    } elseif (Get-Command "gradle" -ErrorAction SilentlyContinue) {
        $buildCmd  = "gradle"
        $buildType = "gradle"
    }
}

if (-not $buildCmd) {
    Write-Error "ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH."
    exit 1
}

Write-Host "[jtest-analyze] Using build command: $buildCmd (type: $buildType)"

# ---------------------------------------------------------------------------
# Run Jtest analysis — customise arguments below for your project
# ---------------------------------------------------------------------------
if ($buildType -eq "maven") {
    & $buildCmd jtest:jtest `
        "-Djtest.config=$($env:JTEST_UTA_CONFIGURATION)" `
        @settingsArg `
        @scopeToTestArg `
        @branchArgs
} else {
    $initScript = Join-Path $env:JTEST_HOME "integration\gradle\init.gradle"
    & $buildCmd jtest `
        "-I$initScript" `
        "-Djtest.config=$($env:JTEST_UTA_CONFIGURATION)" `
        @settingsArg `
        @scopeToTestArg `
        @branchArgs
}

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "ERROR: Jtest analysis exited with code $exitCode."
    exit $exitCode
}

Write-Host "[jtest-analyze] Analysis completed successfully."
exit 0

