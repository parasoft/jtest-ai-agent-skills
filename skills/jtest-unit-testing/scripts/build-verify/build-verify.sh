#!/usr/bin/env bash
# =============================================================================
# build-verify.sh  —  Build the project and run unit tests
#
# Called by the UTA Test Creation skill (always, via SCRIPT_DIR).
#
# Environment variables provided by the skill (always set before this script
# is invoked):
#   JTEST_HOME                        – Jtest installation directory
#   ANALYZED_PROJECT_PATH             – Absolute path to the project root
#   JTEST_STATIC_BASE_REPORT          – Absolute path to base report.xml for TIA (may be empty)
#   JTEST_STATIC_BASE_COVERAGE        – Absolute path to base coverage.xml for TIA (may be empty)
#
# Behaviour:
#   - When both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE are set, runs only
#     the tests affected by changes (TIA mode).
#   - Otherwise runs all tests.
#
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

TEST_CMD=test
TEST_CMD_ARG=${1:-}

if [ -f "./mvnw" ]; then
    BUILD_CMD="./mvnw"
    BUILD_TYPE="maven"
elif [ -f "./gradlew" ]; then
    BUILD_CMD="./gradlew"
    BUILD_TYPE="gradle"
elif command -v mvn >/dev/null 2>&1 && [ -f "${ANALYZED_PROJECT_PATH}/pom.xml" ]; then
    BUILD_CMD="mvn"
    BUILD_TYPE="maven"
elif command -v gradle >/dev/null 2>&1 && [ -f "${ANALYZED_PROJECT_PATH}/build.gradle" ]; then
    BUILD_CMD="gradle"
    BUILD_TYPE="gradle"
else
    echo "ERROR: No build tool found. Provide mvnw, gradlew, mvn, or gradle on PATH." >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Resolve test command argument for specific tests if provided
# ---------------------------------------------------------------------------
if [ -n "${TEST_CMD_ARG:-}" ]; then
    if [ "${BUILD_TYPE:-}" = "maven" ]; then
        TEST_CMD="${TEST_CMD} -Dtest=${TEST_CMD_ARG}"
    elif [ "${BUILD_TYPE:-}" = "gradle" ]; then
        TEST_CMD="${TEST_CMD} --tests ${TEST_CMD_ARG}"
    fi
fi

echo "[build-verify] Using build command: ${BUILD_CMD} (type: ${BUILD_TYPE})"

# ---------------------------------------------------------------------------
# Decide whether to run TIA or full tests
# ---------------------------------------------------------------------------
RUN_TIA=0
if [ -n "${JTEST_STATIC_BASE_REPORT:-}" ] && [ -n "${JTEST_STATIC_BASE_COVERAGE:-}" ] \
    && [ -z "${TEST_CMD_ARG:-}" ]; then
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
    if [ -n "${TEST_CMD_ARG:-}" ]; then
        echo "[build-verify] Running specified tests: ${TEST_CMD_ARG}"
    else
        echo "[build-verify] Running all tests..."
    fi
    ${BUILD_CMD} ${TEST_CMD}
fi

EXIT_CODE=$?

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "ERROR: Build or unit tests failed with exit code ${EXIT_CODE}." >&2
    exit "${EXIT_CODE}"
fi

echo "[build-verify] Build and tests passed."
exit 0
