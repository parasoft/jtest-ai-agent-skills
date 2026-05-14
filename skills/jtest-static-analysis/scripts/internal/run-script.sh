#!/usr/bin/env bash
# =============================================================================
# run-script.sh  —  OS-dispatch helper: invoke a named script from JTEST_STATIC_SCRIPT_DIR
#
# Usage:
#   bash "$JTEST_STATIC_SCRIPT_DIR/internal/run-script.sh" <script-name>
#
# Arguments:
#   $1 — script name: "build-verify" or "jtest-analyze"
#
# Requires:
#   JTEST_STATIC_SCRIPT_DIR — set by resolve-config.sh before this helper is called
#
# Behaviour:
#   Locates $JTEST_STATIC_SCRIPT_DIR/<name>/<name>.sh and executes it with bash.
#   Propagates the script's exit code to the caller unchanged.
#
# Exit codes:
#   As returned by the invoked script.
#   1 — script name missing, JTEST_STATIC_SCRIPT_DIR not set, or script file not found.
# =============================================================================

# Do NOT use set -e here — we need to capture the child's exit code ourselves.
set -uo pipefail

_SCRIPT_NAME="${1:?ERROR: script name argument is required (e.g. build-verify).}"
: "${JTEST_STATIC_SCRIPT_DIR:?ERROR: JTEST_STATIC_SCRIPT_DIR is not set. Run resolve-config first.}"

_SCRIPT_FILE="${JTEST_STATIC_SCRIPT_DIR}/${_SCRIPT_NAME}/${_SCRIPT_NAME}.sh"

if [ ! -f "${_SCRIPT_FILE}" ]; then
    echo "ERROR: [run-script] Script not found: ${_SCRIPT_FILE}" >&2
    exit 1
fi

echo "[run-script] ${_SCRIPT_NAME}"
bash "${_SCRIPT_FILE}"
_EXIT=$?
exit ${_EXIT}

