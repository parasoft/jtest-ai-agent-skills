#!/usr/bin/env bash
# =============================================================================
# build-verify.sh  —  Build the project and run unit tests
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

set -euo pipefail

echo "[build-verify] ANALYZED_PROJECT_PATH = ${ANALYZED_PROJECT_PATH}"

cd "${ANALYZED_PROJECT_PATH}"

# ---------------------------------------------------------------------------
# Detect build wrapper / fall back to system tool
# ---------------------------------------------------------------------------
BUILD_CMD=""
BUILD_TYPE=""

if [ -f "./gradlew" ]; then
    BUILD_CMD="./gradlew"
    BUILD_TYPE="gradle"
elif [ -f "./mvnw" ]; then
    BUILD_CMD="./mvnw"
    BUILD_TYPE="maven"
elif command -v gradle >/dev/null 2>&1 && [ -f "${ANALYZED_PROJECT_PATH}/build.gradle" ]; then
    BUILD_CMD="gradle"
    BUILD_TYPE="gradle"
elif command -v mvn >/dev/null 2>&1 && [ -f "${ANALYZED_PROJECT_PATH}/pom.xml" ]; then
    BUILD_CMD="mvn"
    BUILD_TYPE="maven"
else
    echo "ERROR: No build tool found. Provide gradlew, mvnw, gradle, or mvn on PATH." >&2
    exit 1
fi


echo "[build-verify] Using build command: ${BUILD_CMD} (type: ${BUILD_TYPE})"

# ---------------------------------------------------------------------------
# Decide whether to run TIA or full tests
# ---------------------------------------------------------------------------
RUN_TIA=0
if [ -n "${JTEST_STATIC_BASE_REPORT:-}" ] && [ -n "${JTEST_STATIC_BASE_COVERAGE:-}" ]; then
    RUN_TIA=1
fi

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------
if [ "${RUN_TIA}" -eq 1 ]; then
    echo "[build-verify] Running in TIA mode..."
    if [ "${BUILD_TYPE}" = "maven" ]; then
        # shellcheck disable=SC2086
        ${BUILD_CMD} clean tia:affected-tests test \
            "-Djtest.referenceCoverageFile=${JTEST_STATIC_BASE_COVERAGE}" \
            "-Djtest.referenceReportFile=${JTEST_STATIC_BASE_REPORT}"
    else
        # shellcheck disable=SC2086
        ${BUILD_CMD} clean --no-daemon affectedTests test \
            "-I${JTEST_HOME}/integration/gradle/init.gradle" \
            "-Djtest.referenceCoverageFile=${JTEST_STATIC_BASE_COVERAGE}" \
            "-Djtest.referenceReportFile=${JTEST_STATIC_BASE_REPORT}"
    fi
else
    echo "[build-verify] Running all tests..."
    # shellcheck disable=SC2086
    ${BUILD_CMD} test
fi

EXIT_CODE=$?

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "ERROR: Build or unit tests failed with exit code ${EXIT_CODE}." >&2
    exit "${EXIT_CODE}"
fi

echo "[build-verify] Build and tests passed."
exit 0

