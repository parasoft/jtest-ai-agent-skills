---
name: jtest-unit-testing
description: Run Parasoft UTA Test Creation on Java projects, detect failed tests, and provide fixes to make them run. Use this skill when users want to create automatically new tests, and improve code coverage using UTA and Jtest.
labels:
   - java
   - code-quality
   - jtest
   - parasoft
   - bulk creation
   - UTA
   - coverage
   - tests creation
metadata:
   author: Parasoft
   version: "2.6"
   mode: non-interactive
   requires:
      - Parasoft Jtest installation
      - Maven or Gradle project
---

# UTA Test Creator And Test Modifications Skill

## Overview

This is a main super skill to manage the referred subskills. This skill enables agents to run UTA Tests Creator Analyzer on Java projects to create tests using `jtest-uta-test-creation` subskill, fix failing tests on post-creation stage using `jtest-uta-test-fixing` subskill and finally clean up tests which could not be fixed using `jtest-uta-test-removal` subskill so that finally there were no failing tests left. This skill and all its sub-skills operate only on tests created by UTA in the current run session.

> **Non-interactive / nightly mode**: This skill operates fully autonomously. It **never** prompts the user for input. All required settings must be supplied via environment variables before the skill is invoked. If a required setting cannot be determined automatically, the skill prints a descriptive error message to the console and terminates immediately with a non-zero exit code.

## When to Use This Skill

Use this skill when:
- User wants to run bulk test creation on Java code.
- User mentions Jtest, UTA, automatic test creation or increase coverage.
- User needs to analyze a Maven or Gradle project.
- User mentions improve failing tests, fix failing test, increase coverage, improve maintainability of the project.

## Prerequisites

- `jtest-uta-test-creation` subskill located in `jtest-uta-test-creation` subdirectory from the directory where current skill is located.
- `jtest-uta-test-fixing` subskill located in `jtest-uta-test-fixing` subdirectory from the directory where current skill is located.
- `jtest-uta-test-removal` subskill located in `jtest-uta-test-removal` subdirectory from the directory where current skill is located.

## Critical Constraints

**The variables resolved in [Preparation](#preparation) subsection must be available in the environment for all subsequent steps and subskills.**

**STRICTLY FOLLOW the `Critical Constraints` sections when working with any of the subskills referred in this super skill!**

**Also follow the constraints outlined here when working with the subskills!**

**DO NOT create, modify, or delete any files other than junit test files that have been added and are strictly related to created tests. It is disallowed to modify any source files of the project, even if it would fix a potential bug. If there is any obvious bug found, it can be reported in the final summary.**

**It is strictly forbidden to alter in any way the scripts or configuration files related to the skill.**

Do not generate summary files, markdown reports, tracking documents, analysis notes, or any other auxiliary files in the repository or anywhere else. The only file modifications permitted are:
1. Editing Java junit test files to create new tests or edit the ones added in this run session.
2. Git operations.

## IMPORTANT INSTRUCTIONS TO FOLLOW:

**Use each step always and in order they are enumerated below - unless instructed otherwise.**
**Starting from step 3, it is only allowed to modify or remove tests that were created or modified in the current run session - unless instructed otherwise.**

## How This Skill Works

### Step 1: Resolve Analysis Scope

Inspect the **user's natural-language request** for explicit scope-limiting language and derive zero or more `-Djtest.resources` patterns to restrict the scope for tests creation and post creation phases to the requested subset of the project. If scope-limiting language is detected, join all derived patterns with commas to form the `JTEST_UTA_RESOURCE` value. Names mentioned by user may refer only to source files, not test files, as only source files are considered for test creation.

**Translation rules** (refer to `docs/scope_limitation.txt` in the skill directory for the full pattern syntax):

| User says | Derived `-Djtest.resources` pattern |
|---|---|
| "in package `com.foo`" / "for package `com.foo.bar`" | `**/com/foo/**` (replace `.` with `/`, append `/**`) |
| "in file `ABC`" / "fix `ABC`" / "only `ABC.java`" | `**/ABC.java` (append `.java` if not already present) |
| "in module `auth`" / "in directory `src/auth`" | `**/auth/**` (append `/**`) |
| "in subpackage `com.foo.bar`" (want all descendants) | `**/com/foo/bar/**` |

**Examples:**
- _"Create tests for package `com.foo`"_ → `JTEST_UTA_RESOURCE=**/com/foo/**`
- _"Create tests for file `ABC`"_ → `JTEST_UTA_RESOURCE=**/ABC.java`
- _"Create tests for files `BankService`, `CartService` and `AccountService`"_ → `JTEST_UTA_RESOURCE=**/BankService.java,**/CartService.java,**/AccountService.java`
- _"Analyze only `BankService` and `AccountService`"_ → `JTEST_UTA_RESOURCE=**/BankService.java,**/AccountService.java`

If **no scope-limiting language is present**, set `JTEST_UTA_RESOURCE` to an empty string — the `jtest-analyze` script will run a full-project analysis.

If **scope-limiting language is present, but it resolves to zero files**, then **terminate immediately** and provide feedback to the user. Explain a short summary of why this happened.


### Step 2: Resolve and Validate Configuration

All necessary variables must be set during this step. The variables should be global for the current session and should be available to all subskills. Make sure that the variables are available also to all scripts invoked during the skill execution.

The resolution of variables is done by **`resolve-config`** script located in `[JTEST_UTA_SCRIPT_DIR]/internal` directory. 
To prepare necessary variables:
1. Resolve the values for `JTEST_UTA_RESOURCE` environment variable, checking it in the following order:

   1.1 Set the `JTEST_UTA_RESOURCE` environment variable based on the user's request (see the "Resolve Analysis Scope" step). If `JTEST_UTA_RESOURCE` is still empty try to resolve it from config file as described in **Load Config File** subsection.

   1.2 If `JTEST_UTA_RESOURCE` is still empty, and user wants to run this skill in context of previous changes you made in the project, and the `JTEST_RESOURCE` environment variable is already set, do the following:
      - Set the `JTEST_UTA_RESOURCE` environment variable with the value from `JTEST_RESOURCE`, i.e. `JTEST_UTA_RESOURCE=$JTEST_RESOURCE`.
      - Export `JTEST_UTA_RESOURCE` variable to the environment and remember it during this run session.

   1.3 If `JTEST_UTA_RESOURCE` is still empty, leave it so. The `jtest-analyze` script will run a full-project analysis in this case.
   
2. Check if environmental variable `JTEST_SKILLS_CONFIG` is set.
3. If `JTEST_SKILLS_CONFIG` point to existing file with extension `.config` then:
   - Do steps from **Load Config File** subsection.
4. If `JTEST_SKILLS_CONFIG` is not set do:
   - Locate the the directory with current running skill.
   - In the directory with current running skill locate file `jtest-skills.config`.
   - If such file exists do:
      - Set environmental variable `JTEST_SKILLS_CONFIG` to location of `jtest-skills.config` file.
      - Do steps from **Load Config File** subsection.
   - **otherwise** go by one level up in the directory structure and check if `jtest-skills.config` file exists. 
   - If `jtest-skills.config` is still not found go by one more level up and check again. Repeat this process until the file is found or there are no more parent directories.
   - When file `jtest-skills.config` is found do:
      - Set environmental variable `JTEST_SKILLS_CONFIG` to location of `jtest-skills.config` file.
      - Do steps from **Load Config File** subsection.
   - If file `jtest-skills.config` is not found in any of previous steps, do not set `JTEST_SKILLS_CONFIG`.

#### Load Config File

Before reading any other environment variable, check for a config file:

1. Detect the path for directory where current `SKILL.md` is located, then set it to `DIR_OF_RUNNING_SKILL` variable.
2. Check if `JTEST_UTA_SCRIPT_DIR` variable is set. **If `JTEST_UTA_SCRIPT_DIR` is not set do:**
   - Set `JTEST_UTA_SCRIPT_DIR` to `[DIR_OF_RUNNING_SKILL]/scripts` directory, where `DIR_OF_RUNNING_SKILL` is the directory where currently running `SKILL.md` is located. Use this setting for `JTEST_UTA_SCRIPT_DIR` as default one **only if `JTEST_UTA_SCRIPT_DIR` is not already set**.
   -Export `JTEST_UTA_SCRIPT_DIR` variable to the environment.
3. Invoke the appropriate variant of `resolve-config` script based on your operating system:
   - For Windows (`.bat`): `call "[JTEST_UTA_SCRIPT_DIR]\internal\resolve-config.bat" "[DIR_OF_RUNNING_SKILL]"`
   - For Windows (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_UTA_SCRIPT_DIR]\internal\resolve-config.ps1" -SkillDir "[DIR_OF_RUNNING_SKILL]"`
   - Linux/macOS: `source "[JTEST_UTA_SCRIPT_DIR]/internal/resolve-config.sh" "[DIR_OF_RUNNING_SKILL]"`
4. Validates that required paths exist (`ANALYZED_PROJECT_PATH`, `JTEST_SETTINGS`, `JTEST_UTA_SCRIPT_DIR`). 
   **If validation fails**: print `ERROR: [variable-name]=[value] points to a path that does not exist. Verify the path and retry.` **and terminate immediately!**
5. Validate that `JTEST_UTA_SCRIPT_DIR` contains both `build-verify` and `jtest-analyze` directories, with approproriate script files inside. 
   **If validation fails**: print `ERROR: JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR] is missing required script [script-name]. Provide both build-verify and jtest-analyze scripts and retry.` **and terminate immediately!**
6.  If `resolve-config` runs successfully, **THE FOLLOWING VARIABLES SHOULD BE GLOBALLY AVAILABLE DURING ENTIRE SKILL RUN TO ALL STEPS, SHELLS AND SUB-SHELLS, AND REQUIRED ONES SHOULD NOT BE EMPTY:**
   - `JTEST_HOME` -- required;
   - `ANALYZED_PROJECT_PATH` -- required;
   - `JTEST_UTA_CONFIGURATION` -- required;
   - `JTEST_COMMIT_FIXES` -- required;
   - `JTEST_UTA_SCRIPT_DIR` -- required
   - `JTEST_FIX_ATTEMPTS` -- required;
   - `JTEST_SETTINGS` -- optional, can be empty string if not set; 
   - `JTEST_STATIC_BASE_REPORT` -- optional, can be empty string if not set;
   - `JTEST_STATIC_BASE_COVERAGE` -- optional, can be empty string if not set;
   - `JTEST_UTA_RESOURCE` -- optional, can be empty string if not set;
   - `JTEST_UTA_NO_OF_MAX_FIXES` -- optional, can be empty string if not set;
   - `JTEST_REFERENCE_BRANCH` -- optional, can be empty string if not set.
   - `GIT_WORKSPACE` -- optional, can be empty string if `JTEST_REFERENCE_BRANCH` not set, **otherwise should be resolved automatically by `resolve-config` if `JTEST_REFERENCE_BRANCH` is set**;
   - `GIT_BRANCH` -- optional, can be empty string if `JTEST_REFERENCE_BRANCH` not set, **otherwise should be resolved automatically by `resolve-config` if `JTEST_REFERENCE_BRANCH` is set**;
   **If any validation fails the script prints an `ERROR:` message to stderr and exits with code 1.**
   

### Step 3: Run Parasoft UTA Tests Creator Analyzer

Use `jtest-uta-test-creation` subskill to run Parasoft UTA Tests Creator Analyzer on Java projects and create tests.


### Step 4: Do Parasoft UTA Test Post-Processing To Fix Failing Tests

Use `jtest-uta-test-fixing` subskill to do Parasoft UTA Test Post-Processing on Java projects with generated tests by UTA, and fix failing tests in a post-creation stage.


### Step 5: Remove Persistently Failing Tests

Use `jtest-uta-test-removal` skill as a final step to remove tests that are still failing, ensuring that no failing tests remain in the project.

## Error Handling

All errors are printed to the console (stderr) and cause immediate termination with a non-zero exit code. No user interaction is performed.

| Condition                                              | Console message                                                                     | Action                |
|--------------------------------------------------------|-------------------------------------------------------------------------------------|-----------------------|
| `JTEST_SKILLS_CONFIG` file not found                   | `ERROR: JTEST_SKILLS_CONFIG points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_HOME` not set and jtestcli not on PATH          | `ERROR: JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry.` | Terminate immediately |
| `ANALYZED_PROJECT_PATH` not set or path does not exist | `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` | Terminate immediately |
| jtestcli not found in `JTEST_HOME`                     | `ERROR: jtestcli not found in JTEST_HOME=[JTEST_HOME]. Verify the Jtest installation path.` | Terminate immediately |
| No supported build file found                          | `ERROR: No supported build file (pom.xml, build.gradle) found in ANALYZED_PROJECT_PATH=[ANALYZED_PROJECT_PATH]. Only Maven and Gradle projects are supported.` | Terminate immediately |
| Build or unit tests fail                               | `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` + build output | Terminate immediately |
| Analysis command returns non-zero                      | `ERROR: Jtest analysis exited with code [N]. See output above for details.` | Terminate immediately |
| `JTEST_SETTINGS` file not found                        | `ERROR: JTEST_SETTINGS points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_UTA_SCRIPT_DIR` directory not found             | `ERROR: JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| Required script missing in `JTEST_UTA_SCRIPT_DIR`      | `ERROR: JTEST_UTA_SCRIPT_DIR=[path] is missing required script [script-name]. Provide both build-verify and jtest-analyze scripts and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_REPORT` file not found              | `ERROR: JTEST_STATIC_BASE_REPORT points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_COVERAGE` file not found            | `ERROR: JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_REFERENCE_BRANCH` not found                     | `ERROR: JTEST_REFERENCE_BRANCH is does not exist. Check the settings for JTEST_REFERENCE_BRANCH environment variable and retry.` | Terminate immediately |
| `GIT_WORKSPACE` not found when `JTEST_REFERENCE_BRANCH` is set | `ERROR: GIT_WORKSPACE cannot be resolved automatically. Set GIT_WORKSPACE to the git workspace path and retry.` | Terminate immediately |
| `GIT_BRANCH` not found when `JTEST_REFERENCE_BRANCH` is set | `ERROR: GIT_BRANCH cannot be resolved automatically. Set GIT_BRANCH to the current git branch name and retry.` | Terminate immediately |


## Custom Script Mode

When `JTEST_UTA_SCRIPT_DIR` is set the skill delegates all build and analysis operations to two user-supplied scripts found in that directory. This is the recommended approach for complex projects that require custom Maven/Gradle arguments, multi-module builds, special environment setup, or non-standard Jtest configurations.

### Required Scripts

| Script purpose                       | Windows (`.bat` preferred, `.ps1` fallback) | Linux/macOS        |
|--------------------------------------|---------------------------------------------| -------------------|
| Resolve configuration                | `resolve-config.bat` / `resolve-config.ps1` | `resolve-config.sh`|
| Build the project and run unit tests | `build-verify.bat` / `build-verify.ps1`     | `build-verify.sh`  |
| Run UTA tests generation             | `jtest-analyze.bat` / `jtest-analyze.ps1`   | `jtest-analyze.sh` |

Template scripts are provided in the `scripts/` subdirectory next to this `SKILL.md` file. Copy them into your project or a dedicated directory, customize them, and point `JTEST_UTA_SCRIPT_DIR` at that directory.

### Environment Variables Available to Scripts

The skill guarantees that the following environment variables are set before calling this script:

| Variable                   | Guaranteed value                                        |
|----------------------------|---------------------------------------------------------|
| `JTEST_HOME`               | Resolved Jtest installation path                        |
| `ANALYZED_PROJECT_PATH`    | Resolved project root path                              |
| `JTEST_UTA_CONFIGURATION`  | Resolved test configuration (never empty)               |
| `JTEST_COMMIT_FIXES`       | Resolved commit fixes setting (true or false but never empty) |
| `JTEST_UTA_SCRIPT_DIR`     | Resolved script directory path (never empty)            |
| `JTEST_FIX_ATTEMPTS`       | Resolved fix attempts setting (never empty)             |

### Script Contract

**`build-verify` script**:
- Must build the project and run all unit tests.
- Must exit with code `0` on success, non-zero on any failure.
- May print any output to stdout/stderr; it is captured and shown on failure.

**`jtest-analyze` script**:
- Must invoke Jtest analysis (e.g. via `jtestcli` or the Maven/Gradle Jtest plugin).
- Must exit with code `0` on success, non-zero on any failure.

## Implementation Details

### Build System Detection Logic

1. Check for `pom.xml` in project root => Maven
2. Check for `build.gradle` or `build.gradle.kts` => Gradle
3. If neither found => Error: Unsupported build system

### Exit Code Interpretation

- `0`: Success - analysis completed
- `Non-zero`: Error occurred or violations exceeded threshold

## Integration Notes

This skill integrates with:
- Jtest command-line interface (jtestcli)
- Maven projects via jtest:jtest goal
- Gradle projects via jtest task

## Advanced Features

This skill includes:
- Automated test creation and their fixing in case of failures
- Intelligent test fix generation and application
- Comprehensive verification (unit tests after each fix)
- Git-based change tracking and rollback
