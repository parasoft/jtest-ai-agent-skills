#!/usr/bin/env bash
# =============================================================================
# resolve-config.sh  —  Load, parse, and validate all UTA Test Creation settings
#
# This script is sourced (not executed) by the skill runner or other scripts.
# After sourcing, all resolved variables are exported into the calling shell.
#
# Usage:
#   source "$(dirname "$0")/internal/resolve-config.sh" "<skill_dir>"
#
# Arguments:
#   $1 — SKILL_DIR: absolute path to the skill root directory (contains SKILL.md)
#
# On validation failure the script prints an ERROR message to stderr and
# exits with code 1, which also terminates the sourcing shell (set -e).
#
# Exported variables on success:
#   JTEST_HOME, ANALYZED_PROJECT_PATH, JTEST_UTA_CONFIGURATION, JTEST_COMMIT_FIXES,
#   JTEST_SETTINGS, JTEST_STATIC_BASE_REPORT, JTEST_STATIC_BASE_COVERAGE,
#   JTEST_REFERENCE_BRANCH, GIT_WORKSPACE, GIT_BRANCH,
#   JTEST_UTA_SCRIPT_DIR, JTEST_UTA_RESOURCE, JTEST_FIX_ATTEMPTS, JTEST_UTA_NO_OF_MAX_FIXES
#   (set to empty string when not applicable)
# =============================================================================

set -euo pipefail

_SKILL_DIR="${1:?ERROR: SKILL_DIR argument is required.}"

# ---- helper ----------------------------------------------------------------
_die() { echo "ERROR: $*" >&2; exit 1; }

_set_if_unset() {
    # Sets a variable only if it is currently empty/unset.
    local varname="$1" value="$2"
    if [ -z "${!varname:-}" ]; then
        export "$varname"="$value"
    fi
}

# =============================================================================
# Step 0: Load optional config file
# =============================================================================
_RECOGNIZED_KEYS="JTEST_HOME ANALYZED_PROJECT_PATH JTEST_UTA_CONFIGURATION JTEST_COMMIT_FIXES JTEST_SETTINGS JTEST_STATIC_BASE_REPORT JTEST_STATIC_BASE_COVERAGE JTEST_UTA_SCRIPT_DIR JTEST_UTA_RESOURCE JTEST_FIX_ATTEMPTS JTEST_UTA_NO_OF_MAX_FIXES JTEST_REFERENCE_BRANCH"

if [ -n "${JTEST_SKILLS_CONFIG:-}" ]; then
    [ -f "${JTEST_SKILLS_CONFIG}" ] || _die "JTEST_SKILLS_CONFIG points to a file that does not exist: ${JTEST_SKILLS_CONFIG}. Verify the path and retry."

    while IFS= read -r _line || [ -n "${_line}" ]; do
        # skip blank lines and comments
        [[ -z "${_line}" || "${_line}" =~ ^[[:space:]]*# ]] && continue

        _key="${_line%%=*}"
        _val="${_line#*=}"
        # trim whitespace
        _key="$(echo "${_key}" | xargs)"
        _val="$(echo "${_val}" | xargs)"

        # accept only recognised keys
        if [[ " ${_RECOGNIZED_KEYS} " == *" ${_key} "* ]]; then
            _set_if_unset "${_key}" "${_val}"
        fi
    done < "${JTEST_SKILLS_CONFIG}"
fi

# =============================================================================
# Step 1: Resolve required & optional settings
# =============================================================================

# ---- JTEST_HOME ------------------------------------------------------------
if [ -z "${JTEST_HOME:-}" ]; then
    if command -v jtestcli >/dev/null 2>&1; then
        JTEST_HOME="$(dirname "$(command -v jtestcli)")"
    else
        _die "JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry."
    fi
fi
export JTEST_HOME

# ---- ANALYZED_PROJECT_PATH -----------------------------------------------------------
[ -n "${ANALYZED_PROJECT_PATH:-}" ] && [ -d "${ANALYZED_PROJECT_PATH}" ] \
    || _die "ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry."
export ANALYZED_PROJECT_PATH

# ---- JTEST_UTA_CONFIGURATION -----------------------------------------------
export JTEST_UTA_CONFIGURATION="${JTEST_UTA_CONFIGURATION:-builtin://Create Unit Tests}"

# ---- JTEST_COMMIT_FIXES -----------------------------------------------------
export JTEST_COMMIT_FIXES="${JTEST_COMMIT_FIXES:-false}"

# ---- JTEST_SETTINGS ---------------------------------------------------------
if [ -n "${JTEST_SETTINGS:-}" ]; then
    [ -f "${JTEST_SETTINGS}" ] || _die "JTEST_SETTINGS points to a file that does not exist: ${JTEST_SETTINGS}. Verify the path and retry."
fi
export JTEST_SETTINGS="${JTEST_SETTINGS:-}"

# ---- JTEST_STATIC_BASE_REPORT ------------------------------------------------------
if [ -n "${JTEST_STATIC_BASE_REPORT:-}" ]; then
    [ -f "${JTEST_STATIC_BASE_REPORT}" ] || _die "JTEST_STATIC_BASE_REPORT points to a file that does not exist: ${JTEST_STATIC_BASE_REPORT}. Verify the path and retry."
fi
export JTEST_STATIC_BASE_REPORT="${JTEST_STATIC_BASE_REPORT:-}"

# ---- JTEST_STATIC_BASE_COVERAGE ----------------------------------------------------
if [ -n "${JTEST_STATIC_BASE_COVERAGE:-}" ]; then
    [ -f "${JTEST_STATIC_BASE_COVERAGE}" ] || _die "JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: ${JTEST_STATIC_BASE_COVERAGE}. Verify the path and retry."
fi
export JTEST_STATIC_BASE_COVERAGE="${JTEST_STATIC_BASE_COVERAGE:-}"

# ---- JTEST_UTA_SCRIPT_DIR --------------------------------------------------------------
_SCRIPT_DIR_SOURCE="(default)"
if [ -z "${JTEST_UTA_SCRIPT_DIR:-}" ]; then
    JTEST_UTA_SCRIPT_DIR="${_SKILL_DIR}/scripts"
else
    _SCRIPT_DIR_SOURCE="(override)"
fi
[ -d "${JTEST_UTA_SCRIPT_DIR}" ] || _die "JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: ${JTEST_UTA_SCRIPT_DIR}. Verify the path and retry."

# Validate required scripts exist
_found_build_verify=0
for _name in build-verify/build-verify.sh; do
    [ -f "${JTEST_UTA_SCRIPT_DIR}/${_name}" ] && _found_build_verify=1
done
[ "${_found_build_verify}" -eq 1 ] || _die "JTEST_UTA_SCRIPT_DIR=${JTEST_UTA_SCRIPT_DIR} is missing required script build-verify.sh. Provide both build-verify and jtest-analyze scripts and retry."

_found_jtest_analyze=0
for _name in jtest-analyze/jtest-analyze.sh; do
    [ -f "${JTEST_UTA_SCRIPT_DIR}/${_name}" ] && _found_jtest_analyze=1
done
[ "${_found_jtest_analyze}" -eq 1 ] || _die "JTEST_UTA_SCRIPT_DIR=${JTEST_UTA_SCRIPT_DIR} is missing required script jtest-analyze.sh. Provide both build-verify and jtest-analyze scripts and retry."

export JTEST_UTA_SCRIPT_DIR

# ---- JTEST_RESOURCE (set by the skill before calling; default to empty) ------
export JTEST_RESOURCE="${JTEST_RESOURCE:-}"

# ---- JTEST_UTA_RESOURCE -- UTA scope for testing (set by the skill before calling; default to empty) ------
export JTEST_UTA_RESOURCE="${JTEST_UTA_RESOURCE:-}"

# ---- NUMBER OF EXTRA ATTEMPTS TO FIX THE TEST --------------------------------
export JTEST_FIX_ATTEMPTS="${JTEST_FIX_ATTEMPTS:-3}"

# ---- LIMIT THE APPLICATION OF FIXES FOR TEST -----------------------------------
export JTEST_UTA_NO_OF_MAX_FIXES="${JTEST_UTA_NO_OF_MAX_FIXES:-}"

# ---- JTEST_REFERENCE_BRANCH (optional) -----------------------------------------
export JTEST_REFERENCE_BRANCH="${JTEST_REFERENCE_BRANCH:-}"

# Ensure git context variables do not carry stale values between runs
export GIT_BRANCH=""
export GIT_WORKSPACE=""

# Resolve git context and validate target branch when JTEST_REFERENCE_BRANCH is set
if [ -n "${JTEST_REFERENCE_BRANCH:-}" ]; then
    _solution_dir="${ANALYZED_PROJECT_PATH}"
    if ! command -v git >/dev/null 2>&1; then
        _die "JTEST_REFERENCE_BRANCH is set, but git is not available on PATH. Install git or unset JTEST_REFERENCE_BRANCH."
    fi

    git -C "${_solution_dir}" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
        || _die "JTEST_REFERENCE_BRANCH is set, but the solution directory is not inside a git repository: ${_solution_dir}"

    _git_workspace="$(git -C "${_solution_dir}" rev-parse --show-toplevel 2>/dev/null | tr -d '[:space:]')"
    [ -n "${_git_workspace}" ] \
        || _die "Failed to determine git workspace for solution directory: ${_solution_dir}"

    _git_branch="$(git -C "${_solution_dir}" rev-parse --abbrev-ref HEAD 2>/dev/null | tr -d '[:space:]')"
    [ -n "${_git_branch}" ] \
        || _die "Failed to determine current git branch for solution directory: ${_solution_dir}"

    _target="${JTEST_REFERENCE_BRANCH}"
    _has_local=0
    git -C "${_solution_dir}" show-ref --verify --quiet "refs/heads/${_target}" && _has_local=1

    _has_remote=0
    _remote_refs="$(git -C "${_solution_dir}" for-each-ref --format="%(refname)" "refs/remotes/*/${_target}" 2>/dev/null)"
    [ -n "${_remote_refs}" ] && _has_remote=1

    if [ "${_has_local}" -eq 0 ] && [ "${_has_remote}" -eq 0 ]; then
        _die "JTEST_REFERENCE_BRANCH '${_target}' does not exist in the repository."
    fi

    export GIT_WORKSPACE="${_git_workspace}"
    export GIT_BRANCH="${_git_branch}"
fi

# =============================================================================
# Step 2: Verify Jtest installation
# =============================================================================
if [ ! -x "${JTEST_HOME}/jtestcli" ]; then
    _die "jtestcli not found in JTEST_HOME=${JTEST_HOME}. Verify the Jtest installation path."
fi

# =============================================================================
# Print resolved configuration
# =============================================================================
cat <<EOF
Resolved configuration:
  JTEST_SKILLS_CONFIG          = ${JTEST_SKILLS_CONFIG:-(not set)}
  JTEST_HOME                   = ${JTEST_HOME}
  ANALYZED_PROJECT_PATH        = ${ANALYZED_PROJECT_PATH}
  JTEST_UTA_CONFIGURATION      = ${JTEST_UTA_CONFIGURATION}
  JTEST_COMMIT_FIXES           = ${JTEST_COMMIT_FIXES}
  JTEST_SETTINGS               = ${JTEST_SETTINGS:-(not set)}
  JTEST_STATIC_BASE_REPORT     = ${JTEST_STATIC_BASE_REPORT:-(not set)}
  JTEST_STATIC_BASE_COVERAGE   = ${JTEST_STATIC_BASE_COVERAGE:-(not set)}
  JTEST_UTA_SCRIPT_DIR         = ${JTEST_UTA_SCRIPT_DIR} ${_SCRIPT_DIR_SOURCE}
  ANALYSIS_SCOPE               = ${JTEST_RESOURCE:-(none — full project)}
  JTEST_UTA_RESOURCE           = ${JTEST_UTA_RESOURCE:-(none — full project)}
  JTEST_FIX_ATTEMPTS           = ${JTEST_FIX_ATTEMPTS:-3}
  JTEST_UTA_NO_OF_MAX_FIXES    = ${JTEST_UTA_NO_OF_MAX_FIXES:-(not set)}
  JTEST_REFERENCE_BRANCH       = ${JTEST_REFERENCE_BRANCH:-(not set)}
  GIT_WORKSPACE                = ${GIT_WORKSPACE:-(not set)}
  GIT_BRANCH                   = ${GIT_BRANCH:-(not set)}
EOF

