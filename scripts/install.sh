#!/usr/bin/env bash
#
# install.sh — Parasoft Jtest AI Integration Installer
#
# Installs Jtest MCP tools, AI skills and AI agents into the configuration of one or
# more supported coding agents.
#
# Usage: install.sh <coding-agent> [<coding-agent2> ...]
#

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Derive JTEST_HOME from the script location ($JTEST_HOME/integration/ai/scripts/install.sh).
# An explicit JTEST_HOME environment variable takes precedence if already set.
JTEST_HOME="${JTEST_HOME:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
MCP_SERVER_NAME="jtestmcp"
SUPPORTED_AGENTS="codex-cli, copilot-cli"

# ── helpers ──────────────────────────────────────────────────────────────────

usage() {
    cat << EOF
Usage: $SCRIPT_NAME <coding-agent> [<coding-agent2> ...]

Installs Parasoft Jtest MCP tools and Jtest AI skills for the specified coding agent(s).

  MCP tools source : \$JTEST_HOME/integration/mcp/jtestmcp
  AI skills source : \$JTEST_HOME/integration/ai/skills
  AI agents source : \$JTEST_HOME/integration/ai/agents

Supported coding agents:
  codex-cli      OpenAI Codex CLI
  copilot-cli    GitHub Copilot CLI

Examples:
  $SCRIPT_NAME copilot-cli
  $SCRIPT_NAME codex-cli copilot-cli

Note:
  JTEST_HOME is auto-detected from the script location.
  Override it by setting the JTEST_HOME environment variable before running.
EOF
}

check_prerequisites() {

    if [ ! -f "$JTEST_HOME/integration/mcp/jtestmcp" ]; then
        echo "Error: MCP launcher not found: $JTEST_HOME/integration/mcp/jtestmcp" >&2
        exit 1
    fi

    if [ ! -d "$JTEST_HOME/integration/ai/skills" ]; then
        echo "Error: Skills directory not found: $JTEST_HOME/integration/ai/skills" >&2
        exit 1
    fi
    if [ ! -d "$JTEST_HOME/integration/ai/agents" ]; then
        echo "Error: agents directory not found: $JTEST_HOME/integration/ai/agents" >&2
        exit 1
    fi
}

# Copy an agent file to the target directory.
# $1 = source file name (relative to $JTEST_HOME/integration/ai/agents/)
# $2 = target agents directory
copy_agent() {
    local src_file="$JTEST_HOME/integration/ai/agents/$1"
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
    local src="$JTEST_HOME/integration/ai/skills"

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

    local config_file="$HOME/.copilot/mcp-config.json"
    mkdir -p "$HOME/.copilot"

    if [ -f "$config_file" ] && command -v jq &>/dev/null; then
        local tmp
        tmp="$(mktemp)"
        jq --arg cmd "$JTEST_HOME/integration/mcp/jtestmcp" \
           --arg name "$MCP_SERVER_NAME" \
           '.mcpServers[$name] = {"type":"local","command":$cmd,"tools":["*"],"args":[]}' \
           "$config_file" > "$tmp" && mv "$tmp" "$config_file"
        echo "  Updated MCP configuration in $config_file"
    elif [ -f "$config_file" ]; then
        echo "  Warning: jq not found — cannot automatically update $config_file" >&2
        echo "  Please merge the following configuration into $config_file manually:" >&2
        cat << EOF
{
  "mcpServers": {
    "$MCP_SERVER_NAME": {
      "type": "local",
      "command": "$JTEST_HOME/integration/mcp/jtestmcp",
      "tools": [
        "*"
      ],
      "args": []
    }
  }
}
EOF
    else
        cat > "$config_file" << EOF
{
  "mcpServers": {
    "$MCP_SERVER_NAME": {
      "type": "local",
      "command": "$JTEST_HOME/integration/mcp/jtestmcp",
      "tools": [
        "*"
      ],
      "args": []
    }
  }
}
EOF
        echo "  Written MCP configuration to $config_file"
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

