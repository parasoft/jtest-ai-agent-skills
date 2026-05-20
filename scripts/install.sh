#!/usr/bin/env bash
#
# install.sh — Parasoft Jtest AI Integration Installer
#
# Installs Jtest MCP tools, AI skills and AI agents into the configuration of one or
# more supported coding agents.
#
# Usage: install.sh [--jtest.home <path>] <coding-agent> [<coding-agent2> ...]
#

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# AI_HOME is the parent of the scripts folder (contains skills/ and agents/).
AI_HOME="$(cd "$SCRIPT_DIR/.." && pwd)"
MCP_SERVER_NAME="jtestmcp"
SUPPORTED_AGENTS="codex-cli, copilot-cli"
JTEST_HOME="${JTEST_HOME:-}"

# ── helpers ──────────────────────────────────────────────────────────────────

usage() {
    cat << EOF
Usage: $SCRIPT_NAME [--jtest.home <path>] <coding-agent> [<coding-agent2> ...]

Installs Parasoft Jtest MCP tools and Jtest AI skills for the specified coding agent(s).

  MCP tools source : \$JTEST_HOME/integration/mcp/jtestmcp
  AI skills source : $AI_HOME/skills
  AI agents source : $AI_HOME/agents

Options:
  --jtest.home <path>   Path to the Jtest installation directory.
                        Can also be set via the JTEST_HOME environment variable.

Supported coding agents:
  codex-cli      OpenAI Codex CLI
  copilot-cli    GitHub Copilot CLI

Examples:
  $SCRIPT_NAME --jtest.home /opt/jtest/2025.1 copilot-cli
  $SCRIPT_NAME --jtest.home /opt/jtest/2025.1 codex-cli copilot-cli
  $SCRIPT_NAME copilot-cli                    (requires JTEST_HOME env var)

Note:
  JTEST_HOME must be provided via --jtest.home or the JTEST_HOME environment variable.
EOF
}

check_prerequisites() {

    if [ ! -f "$JTEST_HOME/integration/mcp/jtestmcp" ]; then
        echo "Error: MCP launcher not found: $JTEST_HOME/integration/mcp/jtestmcp" >&2
        exit 1
    fi

    if [ ! -d "$AI_HOME/skills" ]; then
        echo "Error: Skills directory not found: $AI_HOME/skills" >&2
        exit 1
    fi
    if [ ! -d "$AI_HOME/agents" ]; then
        echo "Error: Agents directory not found: $AI_HOME/agents" >&2
        exit 1
    fi
}

# Copy an agent file to the target directory.
# $1 = source file name (relative to $AI_HOME/agents/)
# $2 = target agents directory
copy_agent() {
    local src_file="$AI_HOME/agents/$1"
    local target_dir="$2"

    if [ ! -f "$src_file" ]; then
        return
    fi

    echo "  Copying agent $1 to $target_dir ..."
    mkdir -p "$target_dir"
    cp "$src_file" "$target_dir/"
    echo "  Agent installed."
}

# Copy all skills to the target directory.
# $1 = target skills directory
copy_skills() {
    local target_dir="$1"
    local src="$AI_HOME/skills"

    if [ ! -d "$src" ]; then
        return
    fi

    echo "  Copying skills from $src to $target_dir ..."
    mkdir -p "$target_dir"
    cp -r "$src/." "$target_dir/"
    echo "  Skills installed."
}

# ── per-agent installers ─────────────────────────────────────────────────────

install_copilot_cli() {
    echo ">>> Installing Parasoft Jtest integration for GitHub Copilot CLI ..."

    if command -v copilot &>/dev/null; then
        copilot mcp add --transport stdio "$MCP_SERVER_NAME" "$JTEST_HOME/integration/mcp/jtestmcp"
        echo "  Registered MCP server '$MCP_SERVER_NAME' via Copilot CLI."
    else
        echo "  Warning: 'copilot' CLI not found — cannot register MCP server automatically." >&2
        echo "  Run the following command manually after installing the Copilot CLI:" >&2
        echo "    copilot mcp add --transport stdio $MCP_SERVER_NAME \"$JTEST_HOME/integration/mcp/jtestmcp\"" >&2
    fi

    copy_skills "$HOME/.copilot/skills"
    copy_agent "jtest-fix-violation.md" "$HOME/.copilot/agents"
    echo ">>> GitHub Copilot CLI integration installed."
}


install_codex_cli() {
    echo ">>> Installing Parasoft Jtest integration for Codex CLI ..."

    local config_file="$HOME/.codex/config.toml"
    local section="[mcp_servers.$MCP_SERVER_NAME]"
    local command_entry="command = \"$JTEST_HOME/integration/mcp/jtestmcp\""

    mkdir -p "$HOME/.codex"

    if [ -f "$config_file" ]; then
        if grep -qF "$section" "$config_file"; then
            # Update the existing command entry for this MCP server
            local tmp
            tmp="$(mktemp)"
            awk -v section="$section" -v cmd="$command_entry" '
                $0 == section { print; found=1; next }
                found && /^command[[:space:]]*=/ { print cmd; found=0; next }
                found && /^\[/ { found=0 }
                { print }
            ' "$config_file" > "$tmp" && mv "$tmp" "$config_file"
            echo "  Updated MCP configuration in $config_file"
        else
            printf '\n%s\n%s\n' "$section" "$command_entry" >> "$config_file"
            echo "  Appended MCP configuration to $config_file"
        fi
    else
        cat > "$config_file" << EOF
$section
$command_entry
EOF
        echo "  Written MCP configuration to $config_file"
    fi

    copy_skills "$HOME/.codex/skills"
    copy_agent "jtest-fix-violation.toml" "$HOME/.codex/agents"
    echo ">>> Codex CLI integration installed."
}


# ── main ─────────────────────────────────────────────────────────────────────

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# ── Pre-parse: extract --jtest.home and collect remaining arguments ───────────
remaining_args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --jtest.home)
            if [[ -z "${2:-}" ]]; then
                echo "Error: --jtest.home requires a path value" >&2
                exit 1
            fi
            JTEST_HOME="$2"
            shift 2
            ;;
        *)
            remaining_args+=("$1")
            shift
            ;;
    esac
done
set -- "${remaining_args[@]+"${remaining_args[@]}"}"

if [ $# -eq 0 ]; then
    usage
    exit 0
fi

# ── Validate JTEST_HOME ───────────────────────────────────────────────────────
if [ -z "$JTEST_HOME" ]; then
    echo "Error: JTEST_HOME is not set." >&2
    echo "       Provide it via --jtest.home <path> or set the JTEST_HOME environment variable." >&2
    exit 1
fi

check_prerequisites

overall_exit=0

for agent in "$@"; do
    echo ""
    case "$agent" in
        -h|--help)
            usage
            ;;
        copilot-cli)
            install_copilot_cli
            ;;
        codex-cli)
            install_codex_cli
            ;;
        *)
            echo "Error: Unknown coding agent: '$agent'" >&2
            echo "       Supported agents: $SUPPORTED_AGENTS" >&2
            overall_exit=1
            ;;
    esac
done

exit $overall_exit

