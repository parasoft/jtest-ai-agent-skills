# =============================================================================
# jtest-analyze.ps1  —  Run Jtest static analysis
#
# Called by the Jtest Static Analysis skill (always, via JTEST_STATIC_SCRIPT_DIR).
#
# Environment variables provided by the skill (always set before this script
# is invoked):
#   JTEST_HOME               – Jtest installation directory
#   ANALYZED_PROJECT_PATH             – Absolute path to the project root
#   JTEST_STATIC_CONFIGURATION – Jtest test configuration name
#   JTEST_SETTINGS           – Absolute path to Jtest settings file (may be empty)
#   JTEST_RESOURCE           – Comma-separated resource patterns, e.g.
#                              "**/com/foo/**,**/Bar.java" (may be empty for
#                              full-project analysis). Passed as a single
#                              -Djtest.resources switch.
#   JTEST_REF_REPORT_FILE    – Absolute path to the baseline report.xml used for
#                              fix-verification runs (empty during initial analysis)
#   JTEST_REF_REPORT_EXCLUDE – Set to "false" during fix-verification runs to
#                              include all findings relative to the baseline
#                              (empty during initial analysis)
#   JTEST_REFERENCE_BRANCH      – When set, restricts analysis scope to changes
#                              relative to the specified target branch (git).
#                              GIT_WORKSPACE and GIT_BRANCH must also be set
#                              (resolved automatically by resolve-config).
#
# Exit codes:
#   0  – Analysis completed successfully; report.xml produced
#   1  – Analysis failed
#
# On success, always prints as its last stdout line:
#   REPORT_XML=<absolute_path_to_report.xml>
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
# Build the reference-report arguments (set only during fix-verification runs)
# ---------------------------------------------------------------------------
$refReportArg = @()
if ($env:JTEST_REF_REPORT_FILE -and $env:JTEST_REF_REPORT_FILE -ne "") {
    $refReportArg += "-Dproperty.goal.ref.report.file=`"$($env:JTEST_REF_REPORT_FILE)`""
}
if ($env:JTEST_REF_REPORT_EXCLUDE -and $env:JTEST_REF_REPORT_EXCLUDE -ne "") {
    $refReportArg += "-Dproperty.goal.ref.report.findings.exclude=$($env:JTEST_REF_REPORT_EXCLUDE)"
}

# ---------------------------------------------------------------------------
# Build -Djtest.resources argument from JTEST_RESOURCE (comma-separated)
# ---------------------------------------------------------------------------
$resourceArgs = @()
if ($env:JTEST_RESOURCE -and $env:JTEST_RESOURCE -ne "") {
    $resourceArgs = @("-Djtest.resources=`"$($env:JTEST_RESOURCE)`"")
}

# ---------------------------------------------------------------------------
# Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
# ---------------------------------------------------------------------------
$branchArgs = @()
if ($env:JTEST_REFERENCE_BRANCH -and $env:JTEST_REFERENCE_BRANCH -ne "") {
    $branchArgs += "-Dproperty.scope.scontrol=true"
    $branchArgs += "-Dproperty.scope.scontrol.files.filter.mode=branch"
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

if (Test-Path "gradlew.bat") {
    $buildCmd = ".\gradlew.bat"
    $buildType = "gradle"
}
elseif (Test-Path "mvnw.cmd") {
    $buildCmd = ".\mvnw.cmd"
    $buildType = "maven"
} else {
    if ((Get-Command "gradle" -ErrorAction SilentlyContinue) -and (Test-Path "$env:ANALYZED_PROJECT_PATH\build.gradle")) {
        $buildCmd = "gradle"
        $buildType = "gradle"
    } elseif ((Get-Command "mvn" -ErrorAction SilentlyContinue) -and (Test-Path "$env:ANALYZED_PROJECT_PATH\pom.xml")) {
        $buildCmd = "mvn"
        $buildType = "maven"
    }
}

if (-not $buildCmd) {
    Write-Error "ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH."
    exit 1
}

Write-Host "[jtest-analyze] Using build command: $buildCmd (type: $buildType)"

# ---------------------------------------------------------------------------
# Run Jtest analysis
# ---------------------------------------------------------------------------
if ($buildType -eq "maven") {
    & $buildCmd jtest:jtest `
        "-Djtest.config=$($env:JTEST_STATIC_CONFIGURATION)" `
        @settingsArg `
        @refReportArg `
        @resourceArgs `
        @branchArgs
} else {
    $initScript = Join-Path $env:JTEST_HOME "integration\gradle\init.gradle"
    & $buildCmd jtest `
        "-I$initScript" `
        "-Djtest.config=$($env:JTEST_STATIC_CONFIGURATION)" `
        @settingsArg `
        @refReportArg `
        @resourceArgs `
        @branchArgs
}

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "ERROR: Jtest analysis exited with code $exitCode."
    exit $exitCode
}

# ---------------------------------------------------------------------------
# Resolve, verify, and emit the report path
# ---------------------------------------------------------------------------
if ($buildType -eq "maven") {
    $reportXml = Join-Path $env:ANALYZED_PROJECT_PATH "target\jtest\report.xml"
} else {
    $reportXml = Join-Path $env:ANALYZED_PROJECT_PATH "build\jtest\report.xml"
    if (-not (Test-Path $reportXml -PathType Leaf)) {
        $reportXml = Join-Path $env:ANALYZED_PROJECT_PATH "build\reports\jtest\report.xml"
    }
}

if (-not (Test-Path $reportXml -PathType Leaf)) {
    Write-Error "ERROR: report.xml not found at expected location: $reportXml"
    exit 1
}

Write-Host "[jtest-analyze] Analysis completed successfully."
Write-Host "REPORT_XML=$reportXml"
exit 0
