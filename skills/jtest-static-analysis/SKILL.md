---
name: jtest-static-analysis
description: Run Parasoft Jtest Static Analysis on Java projects, detect violations in user code, and provide fix recommendations. Use this skill when users want to analyze Java code quality, find bugs, security issues, or coding standard violations using Jtest.
labels:
   - java
   - static-analysis
   - code-quality
   - jtest
   - parasoft
metadata:
   author: Parasoft
   version: "2.6"
   mode: non-interactive
   requires:
      - Parasoft Jtest installation
      - Maven or Gradle project
---

# Jtest Static Analysis Skill

## Overview

This skill enables Parasoft Jtest Static Analysis on Java projects, identify violations, and help fix them automatically.

> **Non-interactive / nightly mode**: This skill operates fully autonomously. It **never** prompts the user for input. All required settings must be supplied via environment variables before the skill is invoked. If a required setting cannot be determined automatically, the skill prints a descriptive error message to the console and terminates immediately with a non-zero exit code.

## When to Use This Skill

Use this skill when:
- User wants to run static analysis on Java code
- User mentions Jtest, code quality, or finding bugs/violations
- User needs to analyze a Maven or Gradle project
- User wants to detect security issues, coding standard violations, or best practice issues
- User wants to fix, repair static violations in code

## Prerequisites

All settings are read exclusively from environment variables. No interactive prompts are issued.

All Maven and Gradle commands are executed exclusively through the `build-verify` and `jtest-analyze` scripts located in `JTEST_STATIC_SCRIPT_DIR`. Direct invocation of `mvn`, `mvnw`, `gradle`, or `gradlew` by the skill itself is **never** permitted.

| Variable                       | Required | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                   |
|--------------------------------|---|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `JTEST_SKILLS_CONFIG`          | Optional | Absolute path to a properties file (`key=value` format) from which all other settings below can be loaded. Environment variables always take precedence over values defined in this file.                                                                                                                                                                                                                                                                                     |
| `JTEST_HOME`                   | **Required** (unless auto-detected) | Path to Jtest installation directory (e.g. `C:\Parasoft\jtest` or `/opt/parasoft/jtest`). Auto-detected from `PATH` if not set.                                                                                                                                                                                                                                                                                                                                               |
| `ANALYZED_PROJECT_PATH`        | **Required** | Absolute path to the Java project root to analyse.                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `JTEST_STATIC_CONFIGURATION`   | Optional | Test configuration name (e.g. `builtin://Recommended Rules`). Defaults to `builtin://Recommended Rules`.                                                                                                                                                                                                                                                                                                                                                                      |
| `JTEST_COMMIT_FIXES`           | Optional | Set to `true` to commit each successful fix. Any other value or absence means fixes are left as local uncommitted changes.                                                                                                                                                                                                                                                                                                                                                    |
| `JTEST_STATIC_FILTER_RULE`     | Optional | Comma-separated list of rule IDs. When set, only violations matching these IDs are processed.                                                                                                                                                                                                                                                                                                                                                                                 |
| `JTEST_SETTINGS`               | Optional | Absolute path to a Jtest settings file. When set, adds `-Djtest.settings=<path>` to all analysis commands.                                                                                                                                                                                                                                                                                                                                                                    |
| `JTEST_STATIC_BASE_REPORT`     | Optional | Absolute path to a base `report.xml` file. When set, **Step 3 (Jtest Analysis) is skipped**: this file is used directly as `baseline_report_path` and as the initial source of violations (Step 4), and also as the reference report for incremental/differential analysis during fix verification (Step 6).                                                                                                                                                                  |
| `JTEST_STATIC_BASE_COVERAGE`   | Optional | Absolute path to a base `coverage.xml` file. When set, used as the reference coverage data for incremental/differential analysis.                                                                                                                                                                                                                                                                                                                                             |
| `JTEST_STATIC_NO_OF_MAX_FIXES` | Optional | Maximum number of successful fixes applied in one session. Defaults to `10`. Ignored when the user's prompt specifies an explicit numeric fix limit (e.g. "fix 3 violations" → effective limit = 3). When the cap is reached the skill proceeds directly to Step 7 without processing remaining violations.                                                                                                                                                                   |
| `JTEST_STATIC_SCRIPT_DIR`      | Optional | Absolute path to the scripts root directory. **Defaults to the `scripts/` subdirectory of the skill directory** (the directory containing this `SKILL.md`). The `build-verify` scripts are expected in `[JTEST_STATIC_SCRIPT_DIR]/build-verify/` and the `jtest-analyze` scripts in `[JTEST_STATIC_SCRIPT_DIR]/jtest-analyze/`. Override to supply project-specific scripts. See [Script Execution Mode](#script-execution-mode) for the required script names and interface. |
| `JTEST_REFERENCE_BRANCH`       | Optional | If set, the skill will compare the current branch with the specified reference branch to determine the analysis scope. The reference branch must exist in the repository.                                                                                                                                                                                                                                                                                                     |
## Critical Constraints

**Always EXECUTE scripts by running them in a terminal shell. NEVER read, open, or inspect a script file as a substitute for executing it.** When a step says `Run: run-script <name>` (or its OS-specific equivalent), that means invoke the command in a terminal and wait for its exit code and stdout output. Reading the script file with a file-read tool is forbidden and does not satisfy the step requirement.

**DO NOT create, modify, or delete any files other than the source files strictly required to fix a violation.** Do not generate summary files, markdown reports, tracking documents, analysis notes, or any other auxiliary files in the repository or anywhere else. The only file modifications permitted are:
1. Editing Java source files to apply violation fixes
2. Git operations (commit, revert)

**NEVER fix a violation by suppressing it.** Do not add suppression annotations (e.g. `@SuppressWarnings`), suppression comments (e.g. `// parasoft-suppress`, `// NOPMD`, `// NOSONAR`), or any other suppression mechanism. A fix must resolve the root cause of the violation in the code itself.

**If all violations have been fixed or are suppressed, do NOT rerun analysis under different conditions (e.g. a different test configuration, different scope, or different filter). Assume all work is done, stop immediately with success status and message: "No violations were found for the given scope".**

**Each fix must be committed in its own separate git commit.** Never batch multiple violation fixes into a single commit. A commit must be created immediately after a fix is successfully verified, and before processing the next violation. Each commit must contain changes for exactly one violation only. Commit logic is handled by the `jtest-fix-violation` custom subagent. 

**MCP tool calls MUST be executed one at a time, strictly sequentially and synchronously.** Never invoke two or more MCP tools in parallel or in an overlapping manner. Each MCP tool call must fully complete and its result must be received before the next MCP tool call is initiated. This applies to all MCP tools used in this skill (e.g., `get_violations_from_report_file`, `get_rule_documentation`).

**Step 3 (Jtest Analysis) is skipped when `JTEST_STATIC_BASE_REPORT` is set** — that file is used directly as `baseline_report_path` and as the initial source of violations (Step 4). **If `JTEST_STATIC_BASE_REPORT` is not set, the skill MUST always run the full Jtest analysis first (Step 3) to produce the report before attempting to identify or fix any violations.** Never skip straight to fixing violations without a freshly generated or explicitly provided report.

## How This Skill Works

### Script Invocation

> **EXECUTE, do not read.** Every `Run: run-script <name>` instruction means **run the command in a terminal** and capture its exit code and output. Do not use a file-read tool to inspect the script's source; that is not execution and does not fulfil the step.

All workflow scripts (`build-verify`, `jtest-analyze`) are called through the `run-script` dispatch helper. **Detect the OS once at startup** and use the appropriate variant for every subsequent script call in this skill:

| OS | Command |
|---|---|
| Windows (cmd) | `call "%JTEST_STATIC_SCRIPT_DIR%\internal\run-script.bat" <name>` |
| Windows (PowerShell) | `& "$env:JTEST_STATIC_SCRIPT_DIR\internal\run-script.ps1" -ScriptName <name>` |
| Linux/macOS | `bash "$JTEST_STATIC_SCRIPT_DIR/internal/run-script.sh" <name>` |

`run-script` locates `<JTEST_STATIC_SCRIPT_DIR>/<name>/<name>.<ext>`, prefers `.bat` over `.ps1` on Windows, and propagates the script's exit code unchanged. All subsequent steps use the shorthand `run-script <name>` — substitute the OS-appropriate command from the table above each time.

> **Note:** `resolve-config` is **not** invoked via `run-script` because on Linux/macOS it must be *sourced* (`source ...`) to export variables into the calling shell.

### Step 1: Resolve and Validate Configuration

All configuration loading, parsing, validation, and Jtest installation verification is performed by the **`resolve-config`** script located in `[JTEST_STATIC_SCRIPT_DIR]/internal/` (or the default `scripts/internal/` next to this `SKILL.md`).

**Before calling the script**, set the `JTEST_RESOURCE` environment variable based on the user's request (see [Analysis Scope](#resolve-analysis-scope) below). Then invoke the appropriate variant:

- Windows (`.bat`): `call "[JTEST_STATIC_SCRIPT_DIR]\internal\resolve-config.bat" "<skill_dir>"`
- Windows (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_STATIC_SCRIPT_DIR]\internal\resolve-config.ps1" -SkillDir "<skill_dir>"`
- Linux/macOS: `source "[JTEST_STATIC_SCRIPT_DIR]/internal/resolve-config.sh" "<skill_dir>"`

Where `<skill_dir>` is the absolute path to the directory containing this `SKILL.md`.

The script performs the following (in order):
1. Loads the optional config file from `JTEST_SKILL_CONFIG` (if set), applying `key=value` entries only when the corresponding env var is not already set.
2. Resolves all required and optional variables — applies defaults, auto-detects `JTEST_HOME` from `PATH` if needed.
3. Validates that required paths exist (`ANALYZED_PROJECT_PATH`, `JTEST_SETTINGS`, `JTEST_STATIC_BASE_REPORT`, `JTEST_STATIC_BASE_COVERAGE`, `JTEST_STATIC_SCRIPT_DIR`).
4. Validates that `JTEST_STATIC_SCRIPT_DIR` contains both `build-verify` and `jtest-analyze` scripts.
5. Verifies that `jtestcli` / `jtestcli.exe` exists in `JTEST_HOME`.
6. Prints the full resolved configuration summary to stdout.

**If any validation fails the script prints an `ERROR:` message to stderr and exits with code 1. Terminate the skill immediately on a non-zero exit code.**

After successful return, the following environment variables are guaranteed to be set and available to all subsequent steps: `JTEST_HOME`, `ANALYZED_PROJECT_PATH`, `JTEST_STATIC_CONFIGURATION`, `JTEST_COMMIT_FIXES`, `JTEST_STATIC_FILTER_RULE`, `JTEST_SETTINGS`, `JTEST_STATIC_BASE_REPORT`, `JTEST_STATIC_BASE_COVERAGE`, `JTEST_STATIC_NO_OF_MAX_FIXES`, `JTEST_STATIC_SCRIPT_DIR`, `JTEST_RESOURCE`.

A fully annotated template config file is provided as `jtest-skills.config` in the same directory as this `SKILL.md`. Copy and customise it for each project.

#### Resolve Analysis Scope

Inspect the **user's natural-language request** for explicit scope-limiting language and derive zero or more `-Djtest.resource` patterns to restrict the initial analysis (Step 3) to the requested subset of the project. If scope-limiting language is detected, join all derived patterns with commas to form the `JTEST_RESOURCE` value.

**Translation rules** (refer to `docs/scope_limitation.txt` in the skill directory for the full pattern syntax):

| User says | Derived `-Djtest.resource` pattern |
|---|---|
| "in package `com.foo`" / "for package `com.foo.bar`" | `**/com/foo/**` (replace `.` with `/`, append `/**`) |
| "in file `ABC`" / "fix `ABC`" / "only `ABC.java`" | `**/ABC.java` (append `.java` if not already present) |
| "in module `auth`" / "in directory `src/auth`" | `**/auth/**` (append `/**`) |
| "in subpackage `com.foo.bar`" (want all descendants) | `**/com/foo/bar/**` |

**Examples:**
- _"Fix all violations in package `com.foo`"_ → `JTEST_RESOURCE=**/com/foo/**`
- _"Fix all violations in file `ABC`"_ → `JTEST_RESOURCE=**/ABC.java`
- _"Analyze only `BankService` and `AccountService`"_ → `JTEST_RESOURCE=**/BankService.java,**/AccountService.java`

If **no scope-limiting language** is present, set `JTEST_RESOURCE` to an empty string — the `jtest-analyze` script will run a full-project analysis.

### Step 2: Verify Build and Tests

**Verify unit tests are passing** (compilation is performed implicitly as part of the test run)

   Call the `build-verify` script from `JTEST_STATIC_SCRIPT_DIR`. The following environment variables are already set and are available to the script: `JTEST_HOME`, `ANALYZED_PROJECT_PATH`, `JTEST_STATIC_CONFIGURATION`, `JTEST_SETTINGS`, `JTEST_STATIC_BASE_REPORT`, `JTEST_STATIC_BASE_COVERAGE`, `JTEST_REFERENCE_BRANCH`.

   Run: `run-script build-verify`

   The script handles build-system detection (Maven/Gradle) internally and automatically switches to TIA mode when both `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE` are set. The script **must** exit with code `0` on success and a non-zero code on failure.

   **If the script fails (non-zero exit code)**: print `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` followed by the script output, and terminate immediately.

### Step 3: Run Jtest Analysis

**If `JTEST_STATIC_BASE_REPORT` is set, skip this step entirely and proceed directly to Step 4.**

Otherwise: set `JTEST_RESOURCE` to the comma-separated list of scope patterns derived from the user's request in Step 1 (e.g. `**/com/foo/**,**/Bar.java`), or an empty string if no scope was requested.

Call the `jtest-analyze` script from `JTEST_STATIC_SCRIPT_DIR`. The following environment variables are already set and are available to the script: `JTEST_HOME`, `ANALYZED_PROJECT_PATH`, `JTEST_STATIC_CONFIGURATION`, `JTEST_SETTINGS`, `JTEST_RESOURCE`, `JTEST_REFERENCE_BRANCH`.

Run: `run-script jtest-analyze`

The script handles build-system detection (Maven/Gradle) internally and passes `JTEST_RESOURCE` as a single `-Djtest.resources=<comma-separated-patterns>` switch. The script **must** exit with code `0` on success and a non-zero code on failure, and always prints `REPORT_XML=<absolute_path>` as its **last stdout line** on success.

**If the script fails (non-zero exit code)**: print `ERROR: Jtest analysis exited with code [N]. See output above for details.` and terminate immediately.

### Step 4: Collect Violations

**If `JTEST_STATIC_BASE_REPORT` was set (Step 3 was skipped):** set `baseline_report_path` = `JTEST_STATIC_BASE_REPORT`. Skip the rename instructions below and proceed directly to calling `get_violations_from_report_file`.

**Otherwise (Step 3 was executed):** parse the `REPORT_XML=` value from the last stdout line of `run-script jtest-analyze`. Do not search for `report.xml` in any other location.

**Rename the file at that path to `base_report.xml` within the same directory** (i.e. keep the parent directory unchanged, only replace the filename). Store the resulting absolute path as `baseline_report_path`. Renaming ensures the file is not overwritten by subsequent analysis runs in Step 6.

- Windows (PowerShell): `Rename-Item -Path "<REPORT_XML value>" -NewName "base_report.xml"`
- Linux/macOS: `mv "<REPORT_XML value>" "<parent_dir>/base_report.xml"`

**If the rename fails**, print `ERROR: Failed to rename report file to base_report.xml: [reason]` and terminate immediately.

Call the MCP tool `get_violations_from_report_file` with `baseline_report_path` to obtain a structured list of findings, then report a summary (total count, breakdown by severity).

**Important Notes:**
- Paths to code files between `baseline_report_path` and the local repository may differ; find the best match yourself.
- **Immediately discard any violation whose `suppressed` field is `true`. Suppressed violations must never be fixed or committed.**
- **If there are no violations, stop immediately with success: "No violations were found for the given scope".**

### Step 5: Filter and Prioritize

Process violations in the following deterministic order:
1. **Exclude suppressed violations**: before any other filtering, remove all violations where the `suppressed` field is `true`. These are intentionally silenced by the project team and must not be touched.
2. If any optional filter environment variables were set (`JTEST_STATIC_FILTER_RULE`), apply them exactly as specified.
3. Otherwise, sort all remaining violations by severity (highest first: severity 1 > 2 > 3 > 4 > 5), then by file path alphabetically, then by line number **descending** (highest line number first). This bottom-to-top ordering within each file ensures that fixing a violation does not shift the line numbers of violations yet to be processed in the same file.
4. **Resolve the effective fix limit**:
   - Inspect the user's natural-language request for an explicit numeric fix limit (e.g. "fix 3 violations", "apply at most 5 fixes", "repair 2 issues"). If found, use that number as the effective limit.
   - Otherwise, use `JTEST_STATIC_NO_OF_MAX_FIXES` (default `10`) as the effective limit.
   - Initialize a `successful_fixes` counter to `0`.
5. Process violations in this sorted order, one at a time.

### Step 6: Fix, Verify, and Commit — Delegate to `jtest-fix-violation` Agent

Each fix-verify-commit cycle runs in a **separate agent context** to keep the parent conversation lean.

#### Classifying Violations

- **Simple violations** (formatting, whitespace, unnecessary casts, unused imports) where the fix is purely mechanical and does not change logic — group all such violations for the **same file** into a single batch.
- **All other violations** (logic changes, null checks, resource handling, exception handling, API changes) — process exactly one at a time.

#### Invoking the Agent

For each violation or batch, spawn agent "jtest-fix-violation" and pass a task prompt containing a JSON block. The JSON must include all context the agent needs (it runs in its own isolated context and has no access to the parent's conversation history):

**Single (complex) violation:**
```json
{
  "mode": "single",
  "baselineReportPath": "<baseline_report_path>",
  "scriptDir": "<JTEST_STATIC_SCRIPT_DIR>",
  "analyzedProjectPath": "<ANALYZED_PROJECT_PATH>",
  "commitFixes": <true|false>,
  "violation": {
    "ruleId": "<rule_id>",
    "sourceFile": "<absolute_path>",
    "lineNumber": <line>,
    "message": "<message>",
    "severity": <severity>
  }
}
```

**Batch (simple) violations — same file, pre-sorted line-descending:**
```json
{
  "mode": "batch",
  "baselineReportPath": "<baseline_report_path>",
  "scriptDir": "<JTEST_STATIC_SCRIPT_DIR>",
  "analyzedProjectPath": "<ANALYZED_PROJECT_PATH>",
  "commitFixes": <true|false>,
  "violations": [ ... ]
}
```

The agent performs all fix, verification, retry (up to 3 attempts), and optional commit logic autonomously. 

#### Collecting Results

Parse the `FIX_RESULT=` JSON line from the agent's output. Update counters:

- If `status` is `"SUCCESS"`: increment `successful_fixes` by `violationsFixed`. If `successful_fixes` ≥ the effective fix limit, print `Fix limit of [N] reached. Proceeding to summary.` and proceed immediately to Step 7.
- If `status` is `"FAILURE"`: record the failure and move on to the next violation.

#### Processing Order

**Group violations by source file before dispatching agents.** All violations (or batches) that belong to the same source file **must** be handled by a single agent invocation — never split violations from the same file across multiple agents, as concurrent edits to the same file cause merge conflicts.

After grouping:
- Each group targets a **distinct** source file.
- Multiple groups (targeting different files) **may be dispatched in parallel** — each agent generates its own unique OSGi cache ID to prevent jtestcli cache conflicts when running concurrently.
- Groups that share the same file are merged into one agent invocation before dispatch.

Collect all `FIX_RESULT=` lines once the parallel batch completes, then apply the counter updates from Step 6 in violation-sorted order.

### Step 7: Summary

Report:
- Total fixes attempted
- Successful fixes
- Failures
- Files with uncommitted local changes (if committing was not requested)
- Successful commits (if committing was requested)

## Error Handling

All errors are printed to the console (stderr) and cause immediate termination with a non-zero exit code. No user interaction is performed.

Configuration and validation errors (first group below) are raised by the `resolve-config` script in Step 1. Runtime errors (second group) are raised by the skill directly.

| Condition | Console message | Action |
|---|---|---|
| `JTEST_SKILL_CONFIG` file not found | `ERROR: JTEST_SKILL_CONFIG points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_HOME` not set and jtestcli not on PATH | `ERROR: JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry.` | Terminate immediately |
| `ANALYZED_PROJECT_PATH` not set or path does not exist | `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` | Terminate immediately |
| jtestcli not found in `JTEST_HOME` | `ERROR: jtestcli not found in JTEST_HOME=[JTEST_HOME]. Verify the Jtest installation path.` | Terminate immediately |
| `JTEST_SETTINGS` file not found | `ERROR: JTEST_SETTINGS points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_REPORT` file not found | `ERROR: JTEST_STATIC_BASE_REPORT points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_COVERAGE` file not found | `ERROR: JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_SCRIPT_DIR` directory not found | `ERROR: JTEST_STATIC_SCRIPT_DIR points to a directory that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| Required script missing in `JTEST_STATIC_SCRIPT_DIR` | `ERROR: JTEST_STATIC_SCRIPT_DIR=[path] is missing required script [script-name]. Provide both build-verify and jtest-analyze scripts and retry.` | Terminate immediately |
| Build or unit tests fail | `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` + script output | Terminate immediately |
| Analysis script returns non-zero | `ERROR: Jtest analysis exited with code [N]. See output above for details.` | Terminate immediately |

## Example Workflows

### Example 1: Basic Analysis (Maven, Windows)
```powershell
$env:JTEST_HOME    = "C:\Parasoft\jtest"
$env:ANALYZED_PROJECT_PATH  = "C:\projects\myapp"
# JTEST_STATIC_CONFIGURATION defaults to "builtin://Recommended Rules"
# JTEST_STATIC_SCRIPT_DIR defaults to <skill_dir>/scripts (auto-resolved)

# Skill output (no prompts):
# Resolved configuration:
#   JTEST_STATIC_SCRIPT_DIR = C:\...\jtest-static-analysis\scripts (default)
# Verifying Jtest installation... [OK]
# Running build-verify script... [OK]
# Running jtest-analyze script...
# Analysis complete!
#   Exit Code: 0
#   Violations Found: 15
```

### Example 2: Gradle Project with Custom Config and Commit (Linux/macOS)
```bash
export JTEST_HOME="/opt/parasoft/jtest"
export ANALYZED_PROJECT_PATH="/home/user/myapp"
export JTEST_STATIC_CONFIGURATION="builtin://Find Security Vulnerabilities"
export JTEST_COMMIT_FIXES="true"
# JTEST_STATIC_SCRIPT_DIR defaults to <skill_dir>/scripts (auto-resolved)

# Skill output (no prompts):
# Resolved configuration:
#   JTEST_STATIC_SCRIPT_DIR = /.../jtest-static-analysis/scripts (default)
# Verifying Jtest installation... [OK]
# Running build-verify script... [OK]
# Running jtest-analyze script...
# Violations Found: 23
# Fixing and committing violations...
```

### Example 3: Missing Required Variable (non-zero exit)
```powershell
# JTEST_HOME is not set

# Skill output:
# ERROR: JTEST_HOME is not set and jtestcli was not found on PATH.
#        Set the JTEST_HOME environment variable and retry.
# Exit code: 1
```
