#!/usr/bin/env bash
# =============================================================================
# jtest-analyze.sh  —  Run Jtest static analysis
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

set -euo pipefail

echo "[jtest-analyze] ANALYZED_PROJECT_PATH = ${ANALYZED_PROJECT_PATH}"
echo "[jtest-analyze] JTEST_HOME   = ${JTEST_HOME}"

cd "${ANALYZED_PROJECT_PATH}"

# ---------------------------------------------------------------------------
# Build the -Djtest.settings argument (omit when JTEST_SETTINGS is empty)
# ---------------------------------------------------------------------------
SETTINGS_ARG=""
if [ -n "${JTEST_SETTINGS:-}" ]; then
    SETTINGS_ARG="-Djtest.settings=${JTEST_SETTINGS}"
fi

# ---------------------------------------------------------------------------
# Build the reference-report arguments (set only during fix-verification runs)
# ---------------------------------------------------------------------------
REF_REPORT_ARG=""
if [ -n "${JTEST_REF_REPORT_FILE:-}" ]; then
    REF_REPORT_ARG="-Dproperty.goal.ref.report.file=${JTEST_REF_REPORT_FILE}"
fi

REF_EXCLUDE_ARG=""
if [ -n "${JTEST_REF_REPORT_EXCLUDE:-}" ]; then
    REF_EXCLUDE_ARG="-Dproperty.goal.ref.report.findings.exclude=${JTEST_REF_REPORT_EXCLUDE}"
fi

# ---------------------------------------------------------------------------
# Build -Djtest.resources argument from JTEST_RESOURCE (comma-separated)
# ---------------------------------------------------------------------------
RESOURCE_ARGS=""
if [ -n "${JTEST_RESOURCE:-}" ]; then
    RESOURCE_ARGS="-Djtest.resources=${JTEST_RESOURCE}"
fi

# ---------------------------------------------------------------------------
# Build branch-scope arguments when JTEST_REFERENCE_BRANCH is set
# ---------------------------------------------------------------------------
BRANCH_ARGS=""
if [ -n "${JTEST_REFERENCE_BRANCH:-}" ]; then
    BRANCH_ARGS="-Dproperty.scope.scontrol=true"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scope.scontrol.files.filter.mode=branch"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.type=git"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.git.workspace=${GIT_WORKSPACE}"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scontrol.rep1.git.branch=${GIT_BRANCH}"
    BRANCH_ARGS="${BRANCH_ARGS} -Dproperty.scope.scontrol.ref.branch=${JTEST_REFERENCE_BRANCH}"
fi

# ---------------------------------------------------------------------------
# Build the OSGi cache ID argument (set by each subagent to avoid conflicts
# when multiple agents run jtestcli concurrently)
# ---------------------------------------------------------------------------
CACHE_ID_ARG=""
if [ -n "${JTEST_CACHE_ID:-}" ]; then
    CACHE_ID_ARG="-Djtest.jvmArgs=-Djt.cache.id=${JTEST_CACHE_ID}"
fi

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

echo "[jtest-analyze] Using build command: ${BUILD_CMD} (type: ${BUILD_TYPE})"

# ---------------------------------------------------------------------------
# Run Jtest analysis
# ---------------------------------------------------------------------------
if [ "${BUILD_TYPE}" = "maven" ]; then
    # shellcheck disable=SC2086
    ${BUILD_CMD} jtest:jtest \
        "-Djtest.config=${JTEST_STATIC_CONFIGURATION}" \
        ${SETTINGS_ARG} \
        ${REF_REPORT_ARG} \
        ${REF_EXCLUDE_ARG} \
        ${RESOURCE_ARGS} \
        ${BRANCH_ARGS} \
        ${CACHE_ID_ARG}
else
    # shellcheck disable=SC2086
    ${BUILD_CMD} jtest \
        "-I${JTEST_HOME}/integration/gradle/init.gradle" \
        "-Djtest.config=${JTEST_STATIC_CONFIGURATION}" \
        ${SETTINGS_ARG} \
        ${REF_REPORT_ARG} \
        ${REF_EXCLUDE_ARG} \
        ${RESOURCE_ARGS} \
        ${BRANCH_ARGS} \
        ${CACHE_ID_ARG}
fi

EXIT_CODE=$?

if [ "${EXIT_CODE}" -ne 0 ]; then
    echo "ERROR: Jtest analysis exited with code ${EXIT_CODE}." >&2
    exit "${EXIT_CODE}"
fi

# ---------------------------------------------------------------------------
# Resolve, verify, and emit the report path
# ---------------------------------------------------------------------------
if [ "${BUILD_TYPE}" = "maven" ]; then
    REPORT_XML="${ANALYZED_PROJECT_PATH}/target/jtest/report.xml"
else
    REPORT_XML="${ANALYZED_PROJECT_PATH}/build/jtest/report.xml"
    if [ ! -f "${REPORT_XML}" ]; then
        REPORT_XML="${ANALYZED_PROJECT_PATH}/build/reports/jtest/report.xml"
    fi
fi

if [ ! -f "${REPORT_XML}" ]; then
    echo "ERROR: report.xml not found at expected location: ${REPORT_XML}" >&2
    exit 1
fi

echo "[jtest-analyze] Analysis completed successfully."
echo "REPORT_XML=${REPORT_XML}"
exit 0

