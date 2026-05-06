#!/usr/bin/env bash
# =============================================================================
# jtest-analyze.sh  —  Template for running UTA tests creation
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

set -euo pipefail

echo "[jtest-analyze] ANALYZED_PROJECT_PATH = ${ANALYZED_PROJECT_PATH}"
echo "[jtest-analyze] JTEST_HOME   = ${JTEST_HOME}"

cd "${ANALYZED_PROJECT_PATH}"

# ---------------------------------------------------------------------------
# Build the -Djtest.settings argument (omit when JTEST_SETTINGS is empty)
# ---------------------------------------------------------------------------
SETTINGS_ARG=""
if [ -n "${JTEST_SETTINGS:-}" ]; then
    SETTINGS_ARG="-Djtest.settings=\"${JTEST_SETTINGS}\""
fi

# ---------------------------------------------------------------------------
# Build the -Djtest.resources argument (omit when JTEST_UTA_RESOURCE is empty)
# ---------------------------------------------------------------------------
SCOPE_TO_TEST_ARG=""
if [ -n "${JTEST_UTA_RESOURCE:-}" ]; then
    SCOPE_TO_TEST_ARG="-Djtest.resources=\"${JTEST_UTA_RESOURCE}\""
fi

# ---------------------------------------------------------------------------
# Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
# ---------------------------------------------------------------------------
BRANCH_ARGS=""
if [ -n "${JTEST_REFERENCE_BRANCH:-}" ]; then
    BRANCH_ARGS="-Dproperty.scope.scontrol=true"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scope.scontrol.files.filter.mode=branch"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scope.scontrol.lines.filter.mode=branch"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.type=git"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.git.workspace=${GIT_WORKSPACE}"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.git.branch=${GIT_BRANCH}"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scope.scontrol.ref.branch=${JTEST_REFERENCE_BRANCH}"
fi

# ---------------------------------------------------------------------------
# Detect build wrapper / fall back to system tool
# ---------------------------------------------------------------------------
BUILD_CMD=""
BUILD_TYPE=""

if [ -f "./mvnw" ]; then
    BUILD_CMD="./mvnw"
    BUILD_TYPE="maven"
elif [ -f "./gradlew" ]; then
    BUILD_CMD="./gradlew"
    BUILD_TYPE="gradle"
elif command -v mvn >/dev/null 2>&1; then
    BUILD_CMD="mvn"
    BUILD_TYPE="maven"
elif command -v gradle >/dev/null 2>&1; then
    BUILD_CMD="gradle"
    BUILD_TYPE="gradle"
else
    echo "ERROR: No build tool found. Provide mvnw, gradlew, mvn, or gradle on PATH." >&2
    exit 1
fi

echo "[jtest-analyze] Using build command: ${BUILD_CMD} (type: ${BUILD_TYPE})"

# ---------------------------------------------------------------------------
# Run Jtest analysis — customise arguments below for your project
# ---------------------------------------------------------------------------
if [ "${BUILD_TYPE}" = "maven" ]; then
    # shellcheck disable=SC2086
    ${BUILD_CMD} jtest:jtest \
        "-Djtest.config=${JTEST_UTA_CONFIGURATION}" \
        ${SETTINGS_ARG} \
        ${SCOPE_TO_TEST_ARG} \
        ${BRANCH_ARGS}
else
    # shellcheck disable=SC2086
    ${BUILD_CMD} jtest \
        "-I${JTEST_HOME}/integration/gradle/init.gradle" \
        "-Djtest.config=${JTEST_UTA_CONFIGURATION}" \
        ${SETTINGS_ARG} \
        ${SCOPE_TO_TEST_ARG} \
        ${BRANCH_ARGS}
fi

EXIT_CODE=$?

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "ERROR: Jtest analysis exited with code ${EXIT_CODE}." >&2
    exit "${EXIT_CODE}"
fi

echo "[jtest-analyze] Analysis completed successfully."
exit 0

