# =============================================================================
# build-verify.ps1  —  Build the project and run unit tests
#
# Called by the UTA Test Creation skill (always, via SCRIPT_DIR).
#
# Environment variables provided by the skill (always set before this script
# is invoked):
#   ANALYZED_PROJECT_PATH             – Absolute path to the project root
#   JTEST_STATIC_BASE_REPORT          – Absolute path to base report.xml for TIA (may be empty)
#   JTEST_STATIC_BASE_COVERAGE        – Absolute path to base coverage.xml for TIA (may be empty)
#
# Behaviour:
#   - When both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE are set, runs only
#     the tests affected by changes (TIA mode).
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
$buildCmd = $null
$buildType = $null

$TEST_CMD = @("test")
$TEST_CMD_ARG = $args[0]

if (Test-Path "mvnw.cmd") {
    $buildCmd = ".\mvnw.cmd"
    $buildType = "maven"
}
elseif (Test-Path "gradlew.bat") {
    $buildCmd = ".\gradlew.bat"
    $buildType = "gradle"
} else {
    if ((Get-Command "mvn" -ErrorAction SilentlyContinue) -and (Test-Path "$env:ANALYZED_PROJECT_PATH\pom.xml")) {
        $buildCmd = "mvn"
        $buildType = "maven"
    } elseif ((Get-Command "gradle" -ErrorAction SilentlyContinue) -and (Test-Path "$env:ANALYZED_PROJECT_PATH\build.gradle")) {
        $buildCmd = "gradle"
        $buildType = "gradle"
    }
}

# ---------------------------------------------------------------------------
# Resolve test command argument for specific tests if provided
# ---------------------------------------------------------------------------
if (-not [string]::IsNullOrWhiteSpace($TEST_CMD_ARG)) {
    if ($buildType -eq "maven") {
        $TEST_CMD += "-Dtest=$($TEST_CMD_ARG)"
    } elseif ($buildType -eq "gradle") {
        $TEST_CMD += "--tests"
        $TEST_CMD += $TEST_CMD_ARG
    }
}

if (-not $buildCmd) {
    Write-Error "ERROR: No build tool found. Provide mvnw.cmd, gradlew.bat, mvn, or gradle on PATH."
    exit 1
}

Write-Host "[build-verify] Using build command: $buildCmd"

# ---------------------------------------------------------------------------
# Decide whether to run TIA or full tests
# ---------------------------------------------------------------------------
$runTia = (-not [string]::IsNullOrWhiteSpace($env:JTEST_STATIC_BASE_REPORT) -and 
           -not [string]::IsNullOrWhiteSpace($env:JTEST_STATIC_BASE_COVERAGE) -and 
           [string]::IsNullOrWhiteSpace($TEST_CMD_ARG))

# ---------------------------------------------------------------------------
# Run tests — customize arguments below for your project
# ---------------------------------------------------------------------------
if ($runTia) {
    Write-Host "[build-verify] Running in TIA mode..."
    if ($buildType -eq "maven") {
        & $buildCmd clean tia:affected-tests test `
            "-Djtest.referenceCoverageFile=$($env:JTEST_STATIC_BASE_COVERAGE)" `
            "-Djtest.referenceReportFile=$($env:JTEST_STATIC_BASE_REPORT)"
    } else {
        & $buildCmd clean --no-daemon affectedTests test `
            "-I$($env:JTEST_HOME)/integration/gradle/init.gradle" `
            "-Djtest.referenceCoverageFile=$($env:JTEST_STATIC_BASE_COVERAGE)" `
            "-Djtest.referenceReportFile=$($env:JTEST_STATIC_BASE_REPORT)"
    }
} else {
    if (-not [string]::IsNullOrWhiteSpace($TEST_CMD_ARG)) {
        Write-Host "[build-verify] Running specified tests: $TEST_CMD_ARG"
    } else {
        Write-Host "[build-verify] Running all tests..."
    }   
    & $buildCmd @TEST_CMD
}

$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
    Write-Error "ERROR: Build or unit tests failed with exit code $exitCode."
    exit $exitCode
}

Write-Host "[build-verify] Build and tests passed."
exit 0

