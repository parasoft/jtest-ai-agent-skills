# =============================================================================
# build-verify.ps1  —  Build the project and run unit tests
#
# Called by the Jtest Static Analysis skill (always, via JTEST_STATIC_SCRIPT_DIR).
#
# Environment variables provided by the skill (always set before this script
# is invoked):
#   JTEST_HOME               – Jtest installation directory
#   ANALYZED_PROJECT_PATH             – Absolute path to the project root
#   JTEST_STATIC_CONFIGURATION – Jtest test configuration name
#   JTEST_SETTINGS           – Absolute path to Jtest settings file (may be empty)
#   JTEST_STATIC_BASE_REPORT        – Absolute path to base report.xml for TIA (may be empty)
#   JTEST_STATIC_BASE_COVERAGE      – Absolute path to base coverage.xml for TIA (may be empty)
#
# Behaviour:
#   - When both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE are set, runs only
#     the tests affected by changes (TIA mode).
#   - Otherwise runs all tests.
#
# Exit codes:
#   0  – Build and all unit tests passed
#   1  – Build failed or one or more tests failed
# =============================================================================

$ErrorActionPreference = "Stop"

Write-Host "[build-verify] ANALYZED_PROJECT_PATH = $env:ANALYZED_PROJECT_PATH"

Set-Location -Path $env:ANALYZED_PROJECT_PATH

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

Write-Host "[build-verify] Using build command: $buildCmd (type: $buildType)"

# ---------------------------------------------------------------------------
# Decide whether to run TIA or full tests
# ---------------------------------------------------------------------------
$runTia = ($env:JTEST_STATIC_BASE_REPORT -and $env:JTEST_STATIC_BASE_REPORT -ne "" `
           -and $env:JTEST_STATIC_BASE_COVERAGE -and $env:JTEST_STATIC_BASE_COVERAGE -ne "")

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
if ($runTia) {
    Write-Host "[build-verify] Running in TIA mode..."
    if ($buildType -eq "maven") {
        & $buildCmd clean tia:affected-tests test `
            "-Djtest.referenceCoverageFile=$($env:JTEST_STATIC_BASE_COVERAGE)" `
            "-Djtest.referenceReportFile=$($env:JTEST_STATIC_BASE_REPORT)" `
    } else {
        & $buildCmd clean --no-daemon affectedTests test `
            "-I$($env:JTEST_HOME)/integration/gradle/init.gradle" `
            "-Djtest.referenceCoverageFile=$($env:JTEST_STATIC_BASE_COVERAGE)" `
            "-Djtest.referenceReportFile=$($env:JTEST_STATIC_BASE_REPORT)" `
    }
} else {
    Write-Host "[build-verify] Running all tests..."
    & $buildCmd test
}

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "ERROR: Build or unit tests failed with exit code $exitCode."
    exit $exitCode
}

Write-Host "[build-verify] Build and tests passed."
exit 0
