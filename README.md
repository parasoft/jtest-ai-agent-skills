# Fixing Violations Using AI Coding Agents with Jtest AI Solutions

## Table of Contents

1. [Overview](#overview)
2. [What You Can Achieve with jtest-static-analysis](#what-you-can-achieve-with-jtest-static-analysis)
3. [Integrating Jtest AI Solutions with Your Coding Agent](#integrating-jtest-ai-solutions-with-your-coding-agent)
   - [Prerequisites](#prerequisites)
   - [Installation](#installation)
   - [Supported Coding Agents](#supported-coding-agents)
   - [Integrating with Any Other MCP-Compatible Agent](#integrating-with-any-other-mcp-compatible-agent)
4. [Configuration Reference](#configuration-reference)
   - [Required Settings](#required-settings)
   - [Optional Settings](#optional-settings)
   - [Configuration File](#configuration-file)
5. [Usage Examples](#usage-examples)
   - [Example 1: Basic Full-Project Analysis](#example-1-basic-full-project-analysis)
   - [Example 2: Scoped Analysis — Single Package or File](#example-2-scoped-analysis--single-package-or-file)
   - [Example 3: Custom Script Directory and Settings File](#example-3-custom-script-directory-and-settings-file)
   - [Example 4: Test Impact Analysis for Large Projects](#example-4-test-impact-analysis-for-large-projects)
6. [Best Practices for Reviewing AI-Applied Fixes](#best-practices-for-reviewing-ai-applied-fixes)
7. [Security Considerations](#security-considerations)
   - [Use Coding Agents Responsibly](#use-coding-agents-responsibly)
   - [Grant Only Necessary Tool Access](#grant-only-necessary-tool-access)
   - [Restrict the Agent to Specific Folders](#restrict-the-agent-to-specific-folders)
   - [Configuring Git Commit Access for Codex CLI](#configuring-git-commit-access-for-codex-cli)
8. [CI/CD Integration Workflow](#cicd-integration-workflow)
   - [CI/CD Pipeline Overview](#cicd-pipeline-overview)
   - [Pipeline Stages](#pipeline-stages)
   - [Adapting to other CI systems](#adapting-to-other-ci-systems)
9. [Hands-On Tutorial](#hands-on-tutorial)

---

## Overview

Parasoft Jtest AI Solutions extend your AI coding agent with the ability to detect and automatically fix Java static analysis violations. The integration is built around the **`jtest-static-analysis` skill** — a non-interactive, fully autonomous workflow that drives Jtest analysis, collects violations, delegates each fix to a specialized sub-agent, verifies the result, and optionally commits the change.

The skill works with any Maven or Gradle Java project and integrates with the following coding agents:

| Coding Agent | Identifier |
|---|---|
| GitHub Copilot CLI | `copilot-cli` |
| OpenAI Codex CLI | `codex-cli` |

---

## What You Can Achieve with jtest-static-analysis

The `jtest-static-analysis` skill enables end-to-end automated static analysis and repair:

- **Run Jtest static analysis** against your Java project using any built-in or custom test configuration (e.g. `builtin://Recommended Rules`, `builtin://CWE Top 25 + On the Cusp 2025`).
- **Collect violations** from the generated report, filter by severity, rule, or file scope, and rank them in prioritized order.
- **Fix violations automatically** — the skill delegates each fix to the `jtest-fix-violation` sub-agent, which applies the change, re-runs the build and tests, and retries on failure (up to 3 attempts).
- **Verify fixes** by re-running Jtest analysis incrementally after each change and comparing against the baseline report — the same violation must be gone and no new violations introduced.
- **Commit fixes** individually as separate Git commits when `JTEST_COMMIT_FIXES=true` is set, giving you a clean, reviewable history.
- **Limit scope** to a package, file, module, or branch diff so the agent only touches the code you care about.
- **Operate autonomously in CI/CD** — the skill never prompts for user input; all settings are supplied via config file or environment variables.

### What the skill does NOT do

- It never suppresses a violation using `@SuppressWarnings` or any similar mechanism. Every fix must resolve the root cause.
- It never mixes multiple violation fixes into a single commit.
- It does not create any branches or pull requests on its own — it only commits to the currently checked-out branch. Branch management is left to the user or CI pipeline.
- It never modifies build scripts, documentation files or any other files unrelated with change — only Java source files strictly needed to fix a violation.

---

## Integrating Jtest AI Solutions with Your Coding Agent

### Prerequisites

Before installing the integration:

1. **Parasoft Jtest 2026.1** (or later) must be installed and licensed on the machine where analysis will run.
2. **Java project** must build cleanly with Maven or Gradle, and all existing unit tests must pass before the skill is invoked.
3. The machine running the agent must have access to the Jtest installation directory.
4. **Python 3** is required on Windows for automatic MCP configuration file merging. Without it the installer prints the JSON fragment to add manually.

### Installation

Run the one-step install script from the `scripts` directory of this project. It copies all AI skills and agents, and configures the Jtest MCP server in your agent's configuration.

**Windows (Command Prompt or PowerShell):**

```bat
cd "scripts"
install.bat --jtest.home "C:\Parasoft\jtest" copilot-cli
```

**Linux / macOS:**

```bash
cd "scripts"
chmod +x install.sh
./install.sh --jtest.home /opt/parasoft/jtest copilot-cli
```

The `--jtest.home` argument can be omitted if the `JTEST_HOME` environment variable is already set.

Replace `copilot-cli` with the identifier for your agent (see the table above). Multiple agents can be installed at once:

```bat
install.bat --jtest.home "C:\Parasoft\jtest" copilot-cli codex-cli
```

The installer performs these actions for each agent:

1. Writes or updates the `jtestmcp` MCP server entry in the agent's configuration file.
2. Copies all skills (including `jtest-static-analysis`) to the agent's user-level skills directory.
3. Copies the `jtest-fix-violation` sub-agent definition to the agent's agents directory.

#### What gets installed and where

| Artifact | Source | Windows destination | Linux/macOS destination |
|---|---|---|---|
| MCP server | `[JTEST_HOME]\integration\mcp\jtestmcp.bat` | Registered in agent config | Registered in agent config |
| Skills | `skills\` *(project root)* | `%USERPROFILE%\.copilot\skills\` *(example for Copilot)* | `~/.copilot/skills/` |
| Sub-agent | `agents\` *(project root)* | `%USERPROFILE%\.copilot\agents\` | `~/.copilot/agents/` |

> **Project-local skills (GitHub Copilot):** Skills can also be placed under `.github/skills/` in your repository to share configuration across a team without each developer running the installer.

### Supported Coding Agents

The install script has built-in support for the following two agents:

| Agent | MCP config file | Skills directory |
|---|---|---|
| GitHub Copilot CLI | `%USERPROFILE%\.copilot\mcp-config.json` | `%USERPROFILE%\.copilot\skills\` |
| Codex CLI | `%USERPROFILE%\.codex\config.toml` | `%USERPROFILE%\.codex\skills\` |

> **Note:** The install script modifies configuration files in the user's home directory, which means the registered MCP server, skills, and sub-agents become available for **all invocations of that coding agent under the current user account**. If you prefer to limit the configuration to a single project, most agents support project-level configuration as an alternative.
>
> **GitHub Copilot CLI — project-level configuration:** Place the MCP server registration in `[project]/.github/mcp-config.json`, skills under `[project]/.github/skills/`, and sub-agent definitions under `[project]/.github/agents/`. This way the Jtest integration is active only when Copilot is invoked from within that project.
>
> **Codex CLI — project-level configuration:** Codex CLI has its own mechanism for scoping configuration to a specific project or directory. Refer to the respective coding agent documentation for instructions on how to apply project-level MCP server and skills configuration.

### Integrating with Any Other MCP-Compatible Agent

The install script automates setup for the two agents listed above, but Jtest AI Solutions can be integrated with **any coding agent that supports MCP tools, skills (SKILL.md), and sub-agents**. If your agent is not listed, perform the three steps below manually.

#### Step 1 — Register the Jtest MCP server

Add the `jtestmcp` server to your agent's MCP configuration. The exact format depends on the agent; refer to its documentation for the correct config file location and schema.

**JSON-based agents (most common):**

```json
{
  "mcpServers": {
    "jtestmcp": {
      "command": "<JTEST_HOME>/integration/mcp/jtestmcp",
      "args": []
    }
  }
}
```

On Windows replace the path with `<JTEST_HOME>\integration\mcp\jtestmcp.bat` and escape backslashes: `"C:\\Parasoft\\jtest\\integration\\mcp\\jtestmcp.bat"`.

#### Step 2 — Copy the skills

Copy the entire `jtest-static-analysis` skill directory (and any other skills you need) into the directory your agent reads skills from:

```
Source:      <project-root>/skills/jtest-static-analysis/
Destination: <agent-skills-dir>/jtest-static-analysis/
```

The skill directory must contain `SKILL.md` and the `scripts/` subdirectory. Copy the content recursively so all supporting scripts are included.

#### Step 3 — Copy the sub-agent definition

The `jtest-fix-violation` sub-agent is spawned by the skill to handle each individual fix. Copy the appropriate agent definition file into the directory your agent reads agents from:

| File | Format | Use for |
|---|---|---|
| `<project-root>/agents/jtest-fix-violation.md` | Markdown | Agents that load agents from `.md` files (Copilot) |
| `<project-root>/agents/jtest-fix-violation.toml` | TOML | Agents that load agents from `.toml` files (Codex CLI) |

After completing these three steps, the skill is available in your agent in the same way as for the natively supported agents.

---

## Configuration Reference

All settings are supplied as environment variables. No interactive prompts are issued at runtime.
Alternatively, values can be placed in an optional config file and loaded via `JTEST_SKILLS_CONFIG`.

### Required Settings

| Variable | Description |
|---|---|
| `JTEST_HOME` | Path to the Jtest installation directory (e.g. `C:\Parasoft\jtest`). Auto-detected from `PATH` if not set. |
| `ANALYZED_PROJECT_PATH` | Absolute path to the Java project root to analyse. |

### Optional Settings

| Variable | Default | Description |
|---|---|---|
| `JTEST_STATIC_CONFIGURATION` | `builtin://Recommended Rules` | Test configuration name. Use any built-in profile or a path to a custom `.properties` configuration. Common built-ins: `builtin://Recommended Rules`, `builtin://CWE Top 25 + On the Cusp 2025`. |
| `JTEST_COMMIT_FIXES` | `false` | Set to `true` to automatically commit each successful fix as a separate Git commit. |
| `JTEST_STATIC_FILTER_RULE` | *(all rules)* | Comma-separated rule IDs to process. When set, only violations matching these IDs are fixed. Example: `BD.RES.LEAKS,OWASP2021.A05.SQLI`. |
| `JTEST_SETTINGS` | *(none)* | Absolute path to a Jtest settings `.properties` file. Adds `-Djtest.settings=<path>` to all analysis commands. |
| `JTEST_STATIC_BASE_REPORT` | *(none)* | Absolute path to an existing `report.xml`. When set, Jtest analysis (Step 3) is skipped and this file is used as the baseline. Useful for incremental/differential workflows. See [Example 4](#example-4-test-impact-analysis-for-large-projects) for a TIA setup. |
| `JTEST_STATIC_BASE_COVERAGE` | *(none)* | Absolute path to an existing `coverage.xml`. Used together with `JTEST_STATIC_BASE_REPORT` to enable TIA (test-impact analysis) in the build-verify step — only tests affected by the changed code are re-run, significantly reducing build times for large projects. |
| `JTEST_STATIC_NO_OF_MAX_FIXES` | `10` | Maximum number of successful fixes in one session. Overridden by an explicit number in the agent prompt (e.g. "fix 5 violations"). |
| `JTEST_STATIC_SCRIPT_DIR` | `<skill_dir>/scripts` | Absolute path to the directory containing `build-verify` and `jtest-analyze` scripts. Override for projects that need a custom build or non-standard Maven/Gradle setup. |
| `JTEST_REFERENCE_BRANCH` | *(none)* | Git branch name used as a reference. When set, only violations introduced relative to this branch are analysed. Example: `main`. |
| `JTEST_FIX_ATTEMPTS` | `3` | Number of additional retry attempts for each failing fix before it is recorded as a failure. |
| `JTEST_SKILLS_CONFIG` | *(none)* | Absolute path to a `key=value` config file. Settings in this file are loaded before environment variables, so environment variables always take precedence. |

### Configuration File

For team or project-level configuration, copy the template and set values in a file:

```
<project-root>\jtest-skills.config.template  →  <your-project>\jtest-skills.config
```

Then point the agent to it:

```powershell
# Windows PowerShell
$env:JTEST_SKILLS_CONFIG = "C:\projects\myapp\jtest-skills.config"
```

```bash
# Linux/macOS
export JTEST_SKILLS_CONFIG="/home/user/myapp/jtest-skills.config"
```

Values defined in the file are overridden by any environment variable with the same name, making per-run overrides easy without editing the file.

---

## Usage Examples

### Example 1: Basic Full-Project Analysis

Analyse the entire project using the default `Recommended Rules` configuration and apply up to 10 fixes, leaving them as local uncommitted changes.

**Windows (PowerShell):**

```powershell
$env:JTEST_HOME            = "C:\Parasoft\jtest"
$env:ANALYZED_PROJECT_PATH = "C:\projects\myapp"
$env:JTEST_COMMIT_FIXES    = "false"
```

**Linux/macOS:**

```bash
export JTEST_HOME="/opt/parasoft/jtest"
export ANALYZED_PROJECT_PATH="/home/user/myapp"
export JTEST_COMMIT_FIXES="false"
```

**Agent prompt:**

```
Use jtest-static-analysis to fix violations in priority order.
Fix at most 5 violations in this run. Do not suppress violations.
After each fix, verify the build and re-run Jtest analysis to confirm the violation is gone.
```

---

### Example 2: Scoped Analysis — Single Package or File

Restrict analysis to a specific package or file to keep the session focused and minimise build times.

**Analyse only `com.example.payment` package:**

```powershell
$env:JTEST_HOME            = "C:\Parasoft\jtest"
$env:ANALYZED_PROJECT_PATH = "C:\projects\myapp"
$env:JTEST_COMMIT_FIXES    = "true"
```

**Agent prompt:**

```
Use jtest-static-analysis to fix all severity-1 violations
in package com.example.payment. Commit each fix separately.
Fix at most 3 violations.
```

**Analyse only a single file:**

```
Use jtest-static-analysis to analyse and fix violations in file PaymentService.java only.
```

The skill automatically translates natural-language scope expressions into `-Djtest.resource` patterns:

| User says | Derived pattern |
|---|---|
| "in package `com.example.payment`" | `**/com/example/payment/**` |
| "in file `PaymentService`" | `**/PaymentService.java` |
| "in module `auth`" | `**/auth/**` |
| differences from `main` branch | set `JTEST_REFERENCE_BRANCH=main` |

---

### Example 3: Custom Script Directory and Settings File

For projects with non-standard builds (e.g. multi-module Maven with profiles, or Gradle with custom tasks), supply project-specific `build-verify` and `jtest-analyze` scripts. In this example all settings are kept in a project-local config file so only a single environment variable needs to be set in the shell.

**Step 1 — Create the config file**

Create `.jtest\jtest-skills.config` in your project root (copy from `<project-root>\jtest-skills.config.template` as a starting point) and fill in the values:

```properties
# .jtest/jtest-skills.config

JTEST_HOME=C:\Parasoft\jtest
ANALYZED_PROJECT_PATH=C:\projects\enterprise-app
JTEST_SETTINGS=C:\projects\enterprise-app\jtestcli.properties
JTEST_STATIC_SCRIPT_DIR=C:\projects\enterprise-app\.jtest\scripts
JTEST_STATIC_CONFIGURATION=builtin://CWE Top 25 + On the Cusp 2025
JTEST_COMMIT_FIXES=true
JTEST_STATIC_NO_OF_MAX_FIXES=5
```

**Step 2 — Point the agent to the config file**

Set the `JTEST_SKILLS_CONFIG` environment variable in your shell:

```powershell
# Windows PowerShell
$env:JTEST_SKILLS_CONFIG = "C:\projects\enterprise-app\.jtest\jtest-skills.config"
```

```bash
# Linux/macOS
export JTEST_SKILLS_CONFIG="/home/user/enterprise-app/.jtest/jtest-skills.config"
```

All other settings are loaded from the file at runtime. Any environment variable set in the shell always overrides the corresponding value in the file, which is useful for one-off overrides without editing the file.

**Step 3 — Verify the custom script directory structure**

The directory referenced by `JTEST_STATIC_SCRIPT_DIR` must follow this layout:

```
.jtest\scripts\
    build-verify\
        build-verify.bat   (Windows) or build-verify.sh (Linux/macOS)
    jtest-analyze\
        jtest-analyze.bat  (Windows) or jtest-analyze.sh (Linux/macOS)
    internal\
        run-script.bat / run-script.ps1 / run-script.sh
        resolve-config.bat / resolve-config.ps1 / resolve-config.sh
```

**Agent prompt:**

```
Use jtest-static-analysis to find and fix security vulnerabilities
in the enterprise-app project. Apply fixes to resource-leak and SQL injection
rule violations only. Commit each fix.
```

---

### Example 4: Test Impact Analysis for Large Projects

For large projects, running the full test suite before and after every fix can be prohibitively slow. Jtest supports **Test Impact Analysis (TIA)**, which uses a baseline coverage snapshot to determine which tests are actually affected by a code change and runs only those tests. This can reduce build-verify time dramatically.

> **Recommendation:** Enable TIA for any project where a full test run takes more than a few minutes. The one-time cost of generating the base report is usually recovered after the first two or three fix sessions.

#### Step 1 — Generate the base report and coverage snapshot

Run Jtest with the `jtest-agent` (bytecode instrumentation) enabled so that per-test coverage data is collected. The example below uses Gradle; a Maven equivalent follows.

**Gradle:**

```bash
./gradlew jtest-agent test jtest \
  -Djtest.report=tia \
  -I "$JTEST_HOME/integration/gradle/init.gradle"
```

**Maven:**

```bash
./mvnw jtest:agent test jtest:jtest \
  -Djtest.report=tia
```

Both commands produce two files in the `tia/` subdirectory of the project build output:

| File | Purpose |
|---|---|
| `tia/report.xml` | Baseline violation report — used as `JTEST_STATIC_BASE_REPORT` |
| `tia/coverage.xml` | Per-test coverage data — used as `JTEST_STATIC_BASE_COVERAGE` |

Commit these files to your repository (or store them as CI artifacts) so they can be reused across sessions without re-running the full suite.

#### Step 2 — Configure the skills config file

Update (or create) your project-local `jtest-skills.config` to reference the baseline files:

```properties
# .jtest/jtest-skills.config

JTEST_HOME=C:\Parasoft\jtest
ANALYZED_PROJECT_PATH=C:\projects\large-app
JTEST_STATIC_CONFIGURATION=builtin://Recommended Rules
JTEST_STATIC_BASE_REPORT=C:\projects\large-app\tia\report.xml
JTEST_STATIC_BASE_COVERAGE=C:\projects\large-app\tia\coverage.xml
JTEST_COMMIT_FIXES=true
JTEST_STATIC_NO_OF_MAX_FIXES=10
```

With both baseline files set:
- **Step 3 (Jtest full analysis) is skipped** — the existing `report.xml` is used directly as the source of violations.
- **The build-verify step switches to TIA mode** — only tests whose coverage overlaps the changed lines are executed, not the full suite.

#### Step 3 — Point the agent to the config file

```powershell
# Windows PowerShell
$env:JTEST_SKILLS_CONFIG = "C:\projects\large-app\.jtest\jtest-skills.config"
```

```bash
# Linux/macOS
export JTEST_SKILLS_CONFIG="/home/user/large-app/.jtest/jtest-skills.config"
```

#### Step 4 — Run the agent

```
Use jtest-static-analysis to fix the highest-severity violations.
Fix at most 10 violations. Commit each fix separately.
```

#### Keeping the baseline current

After a batch of fixes is reviewed and merged, regenerate the baseline by repeating Step 1. An outdated baseline may miss new violations introduced since it was created, or trigger unnecessary tests for lines that no longer exist.

---

## Best Practices for Reviewing AI-Applied Fixes

AI-generated fixes are applied one at a time, verified by the build and Jtest re-analysis, and (when `JTEST_COMMIT_FIXES=true`) committed with descriptive messages. Still, human review is essential.

### Read the commit messages

Each commit message generated by the `jtest-fix-violation` agent describes the rule that was violated, the file and line, and the change applied. Read these before merging to understand what was changed and why. A well-formed commit message looks like:

```
Fix BD.RES.LEAKS violation in PaymentService.java:47

Close InputStream in finally block to prevent resource leak.
Jtest rule: BD.RES.LEAKS (severity 1)
```

### Check the code quality

Verify that each fix follows your team's coding standards — naming conventions, error handling patterns, logging style, and architectural boundaries. An AI fix that technically resolves the violation may still introduce patterns that conflict with your codebase conventions.

### Apply incremental fixes for minor remaining issues

If a fix is mostly correct but needs a small adjustment (e.g. a log message phrasing or a variable name), do not revert it. Instead, apply your correction as a separate follow-up commit. This keeps the AI-generated fix attributable and your correction clearly visible in the history.

### Revert when the fix is fundamentally wrong

If an AI-generated fix introduces logic errors, breaks a business invariant, or changes semantics in an unacceptable way — revert the entire commit:

```bash
git revert <commit-sha>
```

Do not attempt to partially fix a fundamentally broken change. A clean revert is easier to understand in the history than a patchwork correction.

### Use a branching strategy

Never run automated fixes directly on `main` or a release branch. Use a dedicated feature or fix branch:

```bash
git checkout -b fix/jtest-violations
# run the agent here
git push origin fix/jtest-violations
# open a pull request for review
```

After review, either merge the branch or cherry-pick individual verified commits from it:

```bash
git cherry-pick <commit-sha>
```

This isolates AI-generated changes and gives the team a natural review gate before they reach the protected branch.

### Do not fix all violations at once

Limit the scope of each agent session. Processing all violations in one run makes review impractical, increases the risk of conflicts, and makes it harder to bisect if something goes wrong. Instead:

- Set `JTEST_STATIC_NO_OF_MAX_FIXES` to a small number (5–10) per session.
- Scope the analysis to a single package or module per run.
- Prioritise severity-1 and severity-2 violations first, then revisit lower-severity items in subsequent sessions.
- Review and merge each batch before starting the next.

### Verify test coverage is maintained

After merging a batch of fixes, check that code coverage has not dropped. If the `jtest-unit-testing` skill is installed, run it after a static-analysis session to generate or update unit tests covering the changed code.

### Keep the baseline report up to date

When using `JTEST_STATIC_BASE_REPORT` for incremental workflows, refresh the baseline after each batch of approved fixes. An outdated baseline can cause the skill to re-report already-fixed violations or mis-classify new ones.

---

## Security Considerations

AI coding agents are powerful tools but they execute code, invoke shell commands, and write files on your behalf. Applying a few basic security principles reduces risk significantly.

### Use Coding Agents Responsibly

Treat a coding agent the same way you treat any automation that has write access to your source code:

- **Review every change before merging.** The agent may produce a technically correct fix that has unintended side effects on business logic or introduces a dependency you do not want. No automated tool replaces human judgement at the merge gate.
- **Run agents in a controlled environment.** Prefer a dedicated CI runner, a container, or a sandboxed development machine. Avoid running agents on machines that have production credentials, database access, or access to secrets beyond what the build requires.
- **Audit agent activity.** Enable commit signing and preserve agent-generated commit messages verbatim. This creates a clear audit trail distinguishing human commits from automated ones.
- **Do not accept AI-generated fixes blindly.** The `jtest-fix-violation` sub-agent is designed to fix one violation at a time and verify the result, but it can still make mistakes. Treat each commit as a candidate fix, not a guaranteed correct change.

### Grant Only Necessary Tool Access

Configure your agent to expose only the MCP tools it actually needs for the `jtest-static-analysis` workflow. Granting access to all available tools increases the attack surface unnecessarily.

The minimum set of MCP tools required by this skill is:

| Tool | Purpose |
|---|---|
| `get_violations_from_report_file` | Read violations from the Jtest report |
| `get_rule_documentation` | Look up rule details when reasoning about a fix |

### Restrict the Agent to Specific Folders

Where your agent supports folder or file-system sandboxing, configure it to operate only on the Java source tree, not on build scripts, CI configuration, secrets files, or other sensitive directories.

**General principles:**

- Allow read/write access to `src/` (or your project's source root).
- Allow read-only access to build output directories if the agent needs to inspect compiled artifacts.
- Deny access to `.git/config`, CI pipeline definitions (`.github/`, `.gitlab-ci.yml`, `Jenkinsfile`), environment files (`.env`, `*.secret`), and any directory containing credentials or certificates.
- If your agent supports an allowlist of file extensions, restrict writes to `.java` files only — the `jtest-fix-violation` agent must never need to modify any other file type.

### Configuring Git Commit Access for Codex CLI

By default, Codex CLI requires explicit permission rules before allowing shell commands. To let the `jtest-fix-violation` agent commit its fixes, add a rule to the Codex rules file.

Create or append to `$HOME/.codex/rules/default.rules`:

```python
# Allow git commit to save fixes made by Codex
prefix_rule(
    pattern      = ["git", "commit"],
    decision     = "allow",
    justification = "Allow git commit so Codex can commit violation fixes",
    match = [
        "git commit -m \"fix violations\"",
        "git commit --all -m \"autofix\"",
    ],
)
```

This rule uses `prefix_rule` to match any `git commit` invocation whose command line begins with `git commit`, while the `match` list further restricts approval to the specific commit message patterns used by the `jtest-fix-violation` agent. Commands that do not match the `match` patterns are not covered by this rule and will still require interactive approval.

> **Tip:** Keep the `match` list as specific as possible. Avoid wildcard patterns such as `"git commit *"` that would silently approve any commit message the agent might produce outside the expected fix workflow.

Other git operations that the agent does **not** need — such as `git push`, `git rebase`, or `git config` — should **not** be added to the allow list. Require interactive approval for those.

---

## CI/CD Integration Workflow

### CI/CD Pipeline Overview

Integrating Jtest AI Solutions into your CI/CD pipeline allows you to automatically detect and fix static analysis violations as part of your normal development workflow. Below is a recommended workflow that balances automation with developer oversight.

### Pipeline Stages

**1. Source Control — Code Repository**

The process is initiated when a developer creates a Pull Request to merge changes into the `main` (or `master`) branch. This event acts as the trigger for all downstream automation.

**2. Build Machine**

The pull request triggers the build machine to automatically start the integration process through three sequential steps:

- **Build Project** — source code is compiled and artifacts are produced.
- **Run Tests** — the full suite of unit and integration tests is executed to ensure functional correctness.
- **Jtest Security Scan** — static analysis is performed using Jtest to identify security vulnerabilities and compliance violations (see [Configuration Reference](#configuration-reference) for available test configurations).

**3. Automated AI Remediation (conditional)**

If violations are found during the Jtest scan, the pipeline branches into an automated remediation flow:

- **Create New Branch** — a dedicated branch is created from the feature branch to contain the AI's fixes, keeping the original branch clean.
- **Trigger AI Coding Agent** — the `jtest-static-analysis` skill is activated with the Jtest report as its baseline (`JTEST_STATIC_BASE_REPORT`), so no second full analysis is needed.
- **Fix Violations** — the agent processes violations in priority order, applies fixes, and verifies each one with a targeted build and re-analysis.
- **Commit Fixed Code** — each verified fix is committed as a separate, descriptive Git commit to the AI branch.

**4. Developer Review and Re-integration**

The developer reviews the AI agent's commits. If satisfied, specific commits are **cherry-picked** from the AI branch back onto the original feature branch:

```bash
git cherry-pick <fix-commit-sha>
```

Commits that are incorrect can simply be left out of the cherry-pick selection. The AI branch can then be discarded.

**5. Code Review and Merge**

Whether the flow came from the normal path (no violations) or the remediation path (fixes cherry-picked), the process continues through the final quality gate:

- **Code Review** — another developer or an automated agent performs a peer review of all changes.
- **Merge to Master** — if all changes are accepted and the pipeline is green, the feature branch is merged into `main`.

---

### Adapting to other CI systems

The same pattern applies to Jenkins, GitLab CI, Azure DevOps, and other systems. The key requirements are:

- Jtest is available on the runner (via installation, container image, or mounted volume).
- The coding agent CLI is installed on the runner.
- The `JTEST_HOME` and `ANALYZED_PROJECT_PATH` environment variables are set.
- The runner has a Git identity configured for commits.
- The `GITHUB_TOKEN` (or equivalent) has write permission to push branches and open pull requests.

For **nightly full-project scans**, schedule the workflow on a cron trigger and drop `JTEST_REFERENCE_BRANCH` to analyse the entire codebase:


---

## Hands-On Tutorial

`SKILL_DEMO.md` (located alongside this guide in `[JTEST_HOME]/integration/ai/`) provides a step-by-step tutorial that walks you through:

1. Confirming prerequisites and setting up the demo project.
2. Installing the skill and MCP tools into GitHub Copilot CLI.
3. Setting the required environment variables for the `[JTEST_HOME]/examples/demo` project.
4. Sending your first prompt to the agent to fix violations.
5. Validating the results with `git diff`.
6. Enabling automatic commit mode.

Start there for a hands-on introduction before applying the skill to your own project.

