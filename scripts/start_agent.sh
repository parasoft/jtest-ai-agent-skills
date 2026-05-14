#!/bin/bash

# This script is used to start the Copilot agent with specific allowed paths and tools. 
# It checks for the ANALYZED_PROJECT_PATH environment variable and sets the current location accordingly. 
# If the ANALYZED_PROJECT_PATH environment variable is not set, it will launch the Copilot agent in the current directory.
# The command to be executed is built from the allowed paths and tools defined in the script.

# Define an array of allowed paths
ALLOWED_PATHS=(
  ${ANALYZED_PROJECT_PATH}
  ${JTEST_HOME}
  ${JTEST_HOME}/integration/ai/skills
)

# Define an array of allowed tools
ALLOWED_TOOLS=(
    "shell"
    "view"
    "create"
    "edit"
    "write"
    "read"
    "grep"
    "glob"
    "memory"
)

# Define an array of denied tools
DENIED_TOOLS=(
#    "shell(git push)"
)

set -eo pipefail
SCRIPT_NAME="$(basename "$0")"
SUPPORTED_AGENTS="copilot"

# Build the paths CMD string
ALLOWED_PATHS_CMD=()
ALLOWED_TOOLS_CMD=()
DENIED_TOOLS_CMD=()

AGENT_CMD=""
RESULTED_CMD=()


help() {
  cat << EOF
Usage: $SCRIPT_NAME <agent-command> [additional-args]
Example: $SCRIPT_NAME copilot --some-flag

Run the specified agent command with preconfigured allowed paths and tools.
The allowed paths could be set in ALLOWED_PATHS array in this script or via --add-dir option.
The allowed and denied tools could be set in ALLOWED_TOOLS and DENIED_TOOLS arrays.

Supported coding agents:
  copilot    GitHub Copilot CLI

Examples:
  $SCRIPT_NAME copilot
  $SCRIPT_NAME copilot --add-dir /path/to/another/allowed/dir

Note:
  The ANALYZED_PROJECT_PATH environment variable can be set to specify the main project directory for the Copilot agent.
  If not set, the agent will be launched in the current directory.
EOF
}

prepare_copilot_cmd() {
    if [ -z "$ANALYZED_PROJECT_PATH" ]; then
      echo "Warning: ANALYZED_PROJECT_PATH environment variable is not set. Copilot agent will be launched in current directory: $(pwd)"
      ALLOWED_PATHS_CMD+=("--add-dir" "$(pwd)")
    else
      cd "$ANALYZED_PROJECT_PATH"
    fi

    for p in "${ALLOWED_PATHS[@]}"; do
      if [ -n "$p" ]; then
        ALLOWED_PATHS_CMD+=(--add-dir "$p")
      fi
    done

    ALLOWED_TOOLS_CMD=$(IFS=', '; echo "${ALLOWED_TOOLS[*]}")
    DENIED_TOOLS_CMD=$(IFS=', '; echo "${DENIED_TOOLS[*]}")

    RESULTED_CMD=("$AGENT_CMD" "${ALLOWED_PATHS_CMD[@]}")

    if [ -n "$ALLOWED_TOOLS_CMD" ]; then
      RESULTED_CMD+=("--allow-tool" "$ALLOWED_TOOLS_CMD")
    fi

    if [ -n "$DENIED_TOOLS_CMD" ]; then
      RESULTED_CMD+=("--deny-tool" "$DENIED_TOOLS_CMD")
    fi
}

#=============================== main =================================

if [ "$#" -lt 1 ]; then
    help
    exit 0
fi

overall_exit=0

cmd=$1
shift

case "$cmd" in
    -h|--help|-H|--HELP)
        help
        overall_exit=0
        ;;
    copilot)
        AGENT_CMD="copilot"
        prepare_copilot_cmd
        ;;
    *)
        echo "Error: Unknown coding agent: '$cmd'" >&2
        echo "       Supported agents: $SUPPORTED_AGENTS" >&2
        overall_exit=1
        ;;
esac

printf '%q' "${RESULTED_CMD[@]}" "$@"
printf '\n'
"${RESULTED_CMD[@]}" "$@"