# Fixing Violations and Improving Test Coverage Using AI Coding Agents with Jtest AI Solutions

## Table of Contents

1. [Overview](#overview)
2. [What You Can Achieve with jtest-static-analysis and jtest-unit-testing](#what-you-can-achieve-with-jtest-static-analysis-and-jtest-unit-testing)
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
   - [Example 2: Increase Test Coverage with Unit Test Generation](#example-2-increase-test-coverage-with-unit-test-generation)
   - [Example 3: Scoped Analysis — Single Package or File](#example-3-scoped-analysis--single-package-or-file)
   - [Example 4: Custom Script Directory and Settings File](#example-4-custom-script-directory-and-settings-file)
   - [Example 5: Test Impact Analysis for Large Projects](#example-5-test-impact-analysis-for-large-projects)
   - [Example 6: Combined Workflow — Violations Then Coverage](#example-6-combined-workflow--violations-then-coverage)
6. [Best Practices for Reviewing AI-Applied Changes](#best-practices-for-reviewing-ai-applied-changes)
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

Parasoft Jtest AI Solutions extend your AI coding agent with two complementary Java workflows: **`jtest-static-analysis`** for detecting and repairing static analysis violations, and **`jtest-unit-testing`** for generating and post-processing unit tests to improve coverage while keeping the project in a passing state.

Both skills are non-interactive, environment-variable driven, and designed for Maven or Gradle Java projects. They can be run independently, but they are typically most effective when used together: first fix priority violations, then generate or update tests around changed code.

The skills integrate with the following coding agents:

| Coding Agent | Identifier |
|---|---|
| GitHub Copilot CLI | `copilot-cli` |
| OpenAI Codex CLI | `codex-cli` |

---

## What You Can Achieve with jtest-static-analysis and jtest-unit-testing

The `jtest-static-analysis` skill enables end-to-end automated static analysis and repair:

- **Run Jtest static analysis** against your Java project using any built-in or custom test configuration (e.g. `builtin://Recommended Rules`, `builtin://CWE Top 25 + On the Cusp 2025`).
- **Collect violations** from the generated report, filter by severity, rule, or file scope, and rank them in prioritized order.
- **Fix violations automatically** — the skill delegates each fix to the `jtest-fix-violation` sub-agent, which applies the change, re-runs the build and tests, and retries on failure (up to 3 attempts).
- **Verify fixes** by re-running Jtest analysis incrementally after each change and comparing against the baseline report — the same violation must be gone and no new violations introduced.

The `jtest-unit-testing` skill enables end-to-end automated unit test generation and post-processing:

- **Run test creation** against your Java project to generate new unit tests for selected scope.
- **Post-process created tests** to obtain the final set of new test and keep the project in a clean passing state.
- **Limit scope** to a package, file, module, or branch diff so test generation targets only the code you care about.
- **Control how much may be fixed** using `JTEST_FIX_ATTEMPTS` and `JTEST_UTA_NO_OF_MAX_FIXES` to keep token usage under control.

### Common features

- **Commit fixes** individually as separate Git commits when `JTEST_COMMIT_FIXES=true` is set, giving you a clean, reviewable history.
- **Limit scope** to a package, file, module, or branch diff so the agent changes only the code you target.
- **Operate autonomously in CI/CD** — no interactive prompts are required during execution; all settings are supplied via config file or environment variables.

### What the skills do NOT do

- **`jtest-static-analysis`** never suppresses a violation using `@SuppressWarnings` or any similar mechanism. Every fix must resolve the root cause.
- **`jtest-static-analysis`** never mixes multiple violation fixes into a single commit.
- **`jtest-unit-testing`** does not modify production source files — it only works with unit tests in order to increase coverage.
- **the skills** do not create branches or pull requests on their own — they only commit to the currently checked-out branch. Branch management is left to the user or CI pipeline.
- **the skills** do not modify build scripts, documentation files, or other unrelated files; they only change files directly required by the active workflow.

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
2. Copies all skills (including `jtest-static-analysis` and `jtest-unit-testing`) to the agent's user-level skills directory.
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

Copy the entire required skill directories into the directory your agent reads skills from:

```
Source:      <project-root>/skills/jtest-static-analysis/
Destination: <agent-skills-dir>/jtest-static-analysis/

Source:      <project-root>/skills/jtest-unit-testing/
Destination: <agent-skills-dir>/jtest-unit-testing/
```

Each skill directory must contain `SKILL.md` and its supporting subdirectories. Copy content recursively.

#### Step 3 — Copy the sub-agent definition (static-analysis only)

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
| `JTEST_UTA_CONFIGURATION` | `builtin://Create Unit Tests` | Test configuration name for `jtest-unit-testing` UTA test creation. |
| `JTEST_COMMIT_FIXES` | `false` | Set to `true` to automatically commit each successful fix as a separate Git commit. |
| `JTEST_STATIC_FILTER_RULE` | *(all rules)* | Comma-separated rule IDs to process. When set, only violations matching these IDs are fixed. Example: `BD.RES.LEAKS,OWASP2021.A05.SQLI`. |
| `JTEST_SETTINGS` | *(none)* | Absolute path to a Jtest settings `.properties` file. Adds `-Djtest.settings=<path>` to all analysis commands. |
| `JTEST_STATIC_BASE_REPORT` | *(none)* | Absolute path to an existing `report.xml`. When set, Jtest analysis (Step 3) is skipped and this file is used as the baseline. Useful for incremental/differential workflows. See [Example 4](#example-4-test-impact-analysis-for-large-projects) for a TIA setup. |
| `JTEST_STATIC_BASE_COVERAGE` | *(none)* | Absolute path to an existing `coverage.xml`. Used together with `JTEST_STATIC_BASE_REPORT` to enable TIA (test-impact analysis) in the build-verify step — only tests affected by the changed code are re-run, significantly reducing build times for large projects. |
| `JTEST_STATIC_NO_OF_MAX_FIXES` | `10` | Maximum number of successful fixes in one session. Overridden by an explicit number in the agent prompt (e.g. "fix 5 violations"). |
| `JTEST_STATIC_SCRIPT_DIR` | `<skill_dir>/scripts` | Absolute path to the directory containing `build-verify` and `jtest-analyze` scripts. Override for projects that need a custom build or non-standard Maven/Gradle setup. |
| `JTEST_UTA_SCRIPT_DIR` | `<skill_dir>/scripts` | Absolute path to the directory containing `build-verify` and `jtest-analyze` scripts for `jtest-unit-testing`. Override for projects that need a custom build or non-standard Maven/Gradle setup. |
| `JTEST_UTA_NO_OF_MAX_FIXES` | *(none)* | Maximum number of test fixes/removals in one `jtest-unit-testing` session. Must be set to a positive number to activate this phase. |
| `JTEST_REFERENCE_BRANCH` | *(none)* | Git branch name used as a reference. When set, only violations introduced relative to this branch are analysed. Example: `main`. |
| `JTEST_FIX_ATTEMPTS` | `3` | Number of additional retry attempts when post-processing failing tests in `jtest-unit-testing`. Affects both fixing static violations and failing tests separately. |
| `JTEST_SKILLS_CONFIG` | *(none)* | Absolute path to a `key=value` config file. Settings in this file are loaded before environment variables, so environment variables always take precedence. |

### Configuration File

For team or project-level configuration, copy the template and set values in a file:

```
<project-root>\jtest-skills.config.template  →  <your-project>\jtest-skills.config
```

Setting `JTEST_SKILLS_CONFIG` is **optional**. The skills automatically discover the config file from two default locations (checked in order) when the variable is not set:

| Priority | Default location | Example |
|---|---|---|
| 1 | Current working directory | `<cwd>/jtest-skills.config` |
| 2 | `.jtest` subfolder of the current directory | `<cwd>/.jtest/jtest-skills.config` |

If neither default location contains the file and `JTEST_SKILLS_CONFIG` is not set, the skills rely entirely on environment variables.

To use a config file in a **non-default location**, point the agent to it explicitly:

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

### Example 2: Increase Test Coverage with Unit Test Generation

Use `jtest-unit-testing` to automatically generate JUnit tests and increase code coverage for an existing project. The skill runs Jtest UTA, collects the generated tests, compiles and runs them, and fixes any failing tests up to the configured limit.

**Windows (PowerShell):**

```powershell
$env:JTEST_HOME              = "C:\Parasoft\jtest"
$env:ANALYZED_PROJECT_PATH   = "C:\projects\myapp"
$env:JTEST_FIX_ATTEMPTS      = "3"
$env:JTEST_COMMIT_FIXES      = "false"
```

**Linux/macOS:**

```bash
export JTEST_HOME="/opt/parasoft/jtest"
export ANALYZED_PROJECT_PATH="/home/user/myapp"
export JTEST_FIX_ATTEMPTS="3"
export JTEST_COMMIT_FIXES="false"
```

**Agent prompt:**

```
Use jtest-unit-testing to increase test coverage for the project.
```

---

### Example 3: Scoped Analysis — Single Package or File

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

```
Use jtest-unit-testing to generate unit tests for the com.example.payment package.
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

### Example 4: Custom Script Directory and Settings File

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

### Example 5: Test Impact Analysis for Large Projects

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

### Example 6: Combined Workflow — Violations Then Coverage

Run both skills in sequence: first fix highest-priority static analysis violations, then generate unit tests to raise coverage around changed code.

**Windows (PowerShell):**

```powershell
$env:JTEST_HOME                  = "C:\Parasoft\jtest"
$env:ANALYZED_PROJECT_PATH       = "C:\projects\myapp"
$env:JTEST_STATIC_CONFIGURATION  = "builtin://Recommended Rules"
$env:JTEST_STATIC_NO_OF_MAX_FIXES= "5"
$env:JTEST_UTA_CONFIGURATION     = "builtin://Create Unit Tests"
$env:JTEST_UTA_NO_OF_MAX_FIXES   = "10"
$env:JTEST_FIX_ATTEMPTS          = "3"
$env:JTEST_COMMIT_FIXES          = "false"
```

**Linux/macOS:**

```bash
export JTEST_HOME="/opt/parasoft/jtest"
export ANALYZED_PROJECT_PATH="/home/user/myapp"
export JTEST_STATIC_CONFIGURATION="builtin://Recommended Rules"
export JTEST_STATIC_NO_OF_MAX_FIXES="5"
export JTEST_UTA_CONFIGURATION="builtin://Create Unit Tests"
export JTEST_UTA_NO_OF_MAX_FIXES= "10"
export JTEST_FIX_ATTEMPTS="3"
export JTEST_COMMIT_FIXES="false"
```

**Agent prompt:**

```
Use jtest-static-analysis to fix severity 1 and severity 2 violations. Then use jtest-unit-testing to increase coverage in the project.
```

---

## Best Practices for Reviewing AI-Applied Changes

AI-generated fixes are applied one at a time, verified by the build and Jtest re-analysis, and (when `JTEST_COMMIT_FIXES=true`) committed with descriptive messages. Still, human review is essential.

### Read the commit messages

Read all agent-generated commits before merging to understand exactly what changed and why.

- For `jtest-static-analysis`, each commit describes the violated rule.
- For `jtest-unit-testing` each commit should contain only generated/updated tests and related post-processing changes.

A static-analysis commit message typically looks like this:

```
Fix BD.RES.LEAKS violation in PaymentService.java:47

Close InputStream in finally block to prevent resource leak.
Jtest rule: BD.RES.LEAKS (severity 1)
```

### Check the code quality

Verify that each change follows your team's standards  — naming conventions, error handling patterns, logging style, and architectural boundaries. For example AI fix that technically resolves the violation may still introduce patterns that conflict with your codebase conventions.

- For `jtest-static-analysis`, confirm the violation is truly resolved without behavior regressions.
- For `jtest-unit-testing`, confirm tests are readable, deterministic, and validate meaningful behavior rather than implementation details.

### Apply incremental fixes for minor remaining issues

If a fix is mostly correct but needs a small adjustment (e.g. a log message phrasing or a variable name), do not revert it. Instead, apply your correction as a separate follow-up commit. This keeps the AI-generated fix attributable and your correction clearly visible in the history.

### Revert when the fix is fundamentally wrong

If an AI-generated fix introduces logic errors, breaks a business invariant, changes semantics in an unacceptable way or invalidates test intent — revert the entire commit:

```bash
git revert <commit-sha>
```

Do not attempt to partially fix a fundamentally broken change. A clean revert is easier to understand in the history than a patchwork correction.

### Use a branching strategy

Never run automated changes directly on `main` or a release branch. Use a dedicated branch:

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

### Do not process everything at once

Limit the scope of each agent session. Processing all violations in one run makes review impractical, increases conflicts, and makes bisection harder. Instead:

- Set `JTEST_STATIC_NO_OF_MAX_FIXES` to a small number (5–10) per session.
- Set `JTEST_UTA_NO_OF_MAX_FIXES` and `JTEST_FIX_ATTEMPTS` to bounded values for test-generation post-processing sessions to lower the cost of time and resources.
- Scope each run to a package, module, file, or diff-focused subset.
- Prioritise severity-1 and severity-2 violations first, then revisit lower-severity items in subsequent sessions.
- Review and merge each batch before starting the next.

### Verify test coverage is maintained

After merging a batch of fixes, check that code coverage has not dropped. If the `jtest-unit-testing` skill is installed, utilise it after a static-analysis session to generate or update unit tests covering the changed code.

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

Configure the agent to expose only the MCP tools it actually needs for your workflow. Granting access to all available tools increases the attack surface unnecessarily.

For `jtest-static-analysis`, the minimum MCP tool set is:

| Tool | Purpose |
|---|---|
| `get_violations_from_report_file` | Read violations from the Jtest report |
| `get_rule_documentation` | Look up rule details when reasoning about a fix |

`jtest-unit-testing` does not require any additional tool access beyond the scripts and file operations needed to generate and post-process tests.

### Restrict the Agent to Specific Folders

Where your agent supports folder or file-system sandboxing, configure it to operate only on the Java source tree, not on build scripts, CI configuration, secrets files, or other sensitive directories.

**General principles:**

- Allow read/write access to source and test folder roots of your project
- Allow read-only access to build output directories if the agent needs to inspect compiled artifacts.
- Deny access to `.git/config`, CI pipeline definitions (`.github/`, `.gitlab-ci.yml`, `Jenkinsfile`), environment files (`.env`, `*.secret`), and any directory containing credentials or certificates.
- If your agent supports an allowlist of file extensions, restrict writes to `.java` test/source files only. `jtest-static-analysis` should modify only source files required to resolve violations, while `jtest-unit-testing` should modify only generated/updated test files for the active session.

### Configuring Git Commit Access for Codex CLI

By default, Codex CLI requires explicit permission rules before allowing shell commands. To let skill workflows commit the changes, add constrained rules to the Codex rules file.

Create or append to `$HOME/.codex/rules/default.rules`:

```python
# Allow git commit to save skill-generated changes made by Codex
prefix_rule(
    pattern      = ["git", "commit"],
    decision     = "allow",
    justification = "Allow git commit so Codex can commit violation fixes and generated tests",
    match = [
        "git commit -m \"fix violations\"",
        "git commit --all -m \"autofix\"",
        "git commit -m \"add UTA generated tests\"",
        "git commit -m \"add UTA fixed tests\"",
    ],
)
```

This rule uses `prefix_rule` to match any `git commit` invocation whose command line begins with `git commit`, while the `match` list further restricts approval to the message patterns used in your approved workflows. Commands that do not match remain interactive.

> **Tip:** Keep the `match` list as specific as possible. Avoid wildcard patterns such as `"git commit *"` that would silently approve any commit message the agent might produce outside the expected fix workflow.

Other git operations that the agent does **not** need — such as `git push`, `git rebase`, or `git config` — should **not** be added to the allow list. Require interactive approval for those.

---

## CI/CD Integration Workflow

### CI/CD Pipeline Overview

Integrating Jtest AI Solutions into your CI/CD pipeline allows you to automatically detect and fix static-analysis violations, then improve test coverage with generated tests. Below is a recommended workflow that balances automation with developer oversight.

### Pipeline Stages

**1. Source Control — Code Repository**

The process is initiated when a developer creates a Pull Request to merge changes into the `main` (or `master`) branch. This event acts as the trigger for all downstream automation.

**2. Build Machine**

The pull request triggers the build machine to automatically start the integration process through three sequential steps:

- **Build Project** — source code is compiled and artifacts are produced.
- **Run Tests** — the full suite of unit and integration tests is executed to ensure functional correctness.
- **Jtest Analysis and Unit Test Creation** — static analysis is performed to identify violations; the same stage can end with unit-test generation (see [Configuration Reference](#configuration-reference)).

**3. Automated AI Remediation (conditional)**

If violations are found, or coverage gates are not met, the pipeline enters an automated remediation flow:

- **Create New Branch** — a dedicated branch is created from the feature branch to contain the AI's fixes, keeping the original branch clean.
- **Trigger AI Coding Agent** — the `jtest-static-analysis` skill is activated with the Jtest report as its baseline (`JTEST_STATIC_BASE_REPORT`), so no second full analysis is needed.
- **Fix Violations** — the agent processes violations in priority order, applies fixes, and verifies each one with a targeted build and re-analysis.
- **Generate Unit Tests** — run `jtest-unit-testing` to increase coverage around changed code and keep the project passing.
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
- Skill-specific configuration is set for the intended stage (`JTEST_STATIC_CONFIGURATION` and/or `JTEST_UTA_CONFIGURATION`).
- The runner has a Git identity configured for commits.
- The `GITHUB_TOKEN` (or equivalent) has write permission to push branches and open pull requests.

For **nightly full-project scans**, schedule the workflow on a cron trigger and drop `JTEST_REFERENCE_BRANCH` to analyse the entire codebase:


---

## Hands-On Tutorial

`SKILL_DEMO.md` (located alongside this guide in `[JTEST_HOME]/integration/ai/`) provides a step-by-step tutorial that walks you through:

1. Confirming prerequisites and setting up the demo project.
2. Installing skills and MCP tools into GitHub Copilot CLI.
3. Setting the required environment variables for the `[JTEST_HOME]/examples/demo` project.
4. Sending your first prompt to fix violations with `jtest-static-analysis`.
5. Running `jtest-unit-testing` to generate tests and improve coverage.
6. Validating the results with `git diff`.
7. Enabling automatic commit mode.

Start there for a hands-on introduction before applying the skills to your own project.

