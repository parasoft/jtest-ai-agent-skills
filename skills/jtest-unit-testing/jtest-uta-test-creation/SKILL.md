---
name: jtest-uta-test-creation
description: Run Parasoft UTA Test Creation on Java projects, detect failed tests, and provide fixes to make them run. Use this skill when users want to create automatically new tests, and improve code coverage using Jtest.
labels:
   - java
   - test generation
   - jtest
   - parasoft
   - bulk creation
   - UTA
   - coverage
metadata:
   author: Parasoft
   version: "2.6"
   mode: non-interactive
   requires:
      - Parasoft Jtest installation
      - Maven or Gradle project
---

# UTA Tests Creator Analyzer Skill

## Overview

This skill enables agents to run Parasoft UTA Tests Creator Analyzer on Java projects and create tests.

> **Non-interactive / nightly mode**: This skill operates fully autonomously. It **never** prompts the user for input. All required settings must be provided via environmental variables or in `.config` file before skill is invoked. If a required setting cannot be determined automatically, the skill prints a descriptive error message to the console and terminates immediately with a non-zero exit code.

## When to Use This Skill

Use this skill when:
- It is referred from `jtest-unit-testing` skill.
- User wants to run bulk test creation on Java code.
- User mentions Jtest, UTA, automatic test creation or increase coverage.
- User needs to analyze a Maven or Gradle project.

## Prerequisites

All settings are read from environment variables or provided by parent super skill or previous steps. No interactive prompts are issued.
**The following variables must be set before invoking the skill:**

| Variable                    | Required | Description |
|-----------------------------|----------|-------------|
| `JTEST_SKILLS_CONFIG`       | Optional | Absolute path to a properties file (`key=value` format) from which all other settings below can be loaded. Environment variables always take precedence over values defined in this file. |
| `JTEST_HOME`                | **Required** (unless auto-detected) | Path to Jtest installation directory (e.g. `C:\Parasoft\jtest` or `/opt/parasoft/jtest`). Auto-detected from `PATH` if not set. |
| `ANALYZED_PROJECT_PATH`     | **Required** | Absolute path to the Java project root to analyze. |
| `JTEST_UTA_CONFIGURATION`   | Optional | Test configuration name (e.g. `builtin://Create Unit Tests`). Defaults to `builtin://Create Unit Tests`. |
| `JTEST_COMMIT_FIXES`        | Optional | Set to `true` to commit each successful fix. Any other value or absence means fixes are left as local uncommitted changes. |
| `JTEST_SETTINGS`            | Optional | Absolute path to a Jtest settings file. When set, adds `-Djtest.settings=<path>` to all analysis commands. |
| `JTEST_UTA_RESOURCE`        | Optional | List of patterns that will resolve the files under tests inside analysis run. Several patterns should be separated by comma. When set, adds `-Djtest.resources=<pattern(s)>` to all analysis commands. |
| `JTEST_UTA_SCRIPT_DIR`      | Optional | Absolute path to a directory containing custom build/analysis scripts. When set, the skill calls the scripts in this directory instead of invoking Maven/Gradle directly. See [Custom Script Mode](#custom-script-mode) for the required script names and interface. |
| `JTEST_STATIC_BASE_REPORT`   | Optional | Absolute path to a base `report.xml` file. |
| `JTEST_STATIC_BASE_COVERAGE` | Optional | Absolute path to a base `coverage.xml` file. |
| `JTEST_REFERENCE_BRANCH`     | Optional | Name of the reference branch for comparison. |
| `GIT_WORKSPACE`              | Conditionally optional | Absolute path to the git workspace. Should be resolved automatically by `resolve-config` if `JTEST_REFERENCE_BRANCH` is set. |
| `GIT_BRANCH`                 | Conditionally optional | Name of the current git branch. Should be resolved automatically by `resolve-config` if `JTEST_REFERENCE_BRANCH` is set. |


## Critical Constraints

**If `JTEST_COMMIT_FIXES=true` - then created tests must be committed in their own separate git commit.**

**No user interaction is permitted at any point. All values must come from environment variables, the config file, or be auto-detected. If a required value cannot be determined, print a clear error message to the console and terminate immediately with a non-zero exit code.**

## IMPORTANT INSTRUCTIONS TO FOLLOW:
1. Strictly implement each step one by one, consequently. 
2. After successful implementation of the step briefly report the result form the step.
3. Treat variables in Prerequisites as global ones.
4. **DO NOT CHANGE THE VARIABLES FROM Prerequisites! THEY ARE FINAL!**
5. USE RESULTS FROM PREVIOUS STEP IN NEXT STEP.

## How This Skill Works

### Step 1: Resolve Required Settings from Environment

#### Resolve `JTEST_HOME`

1. Read the `JTEST_HOME` environment variable:
   - Windows (PowerShell): `$env:JTEST_HOME`
   - Windows (cmd): `%JTEST_HOME%`
   - Linux/macOS: `$JTEST_HOME`
2. If not set, search `PATH` for `jtestcli` / `jtestcli.exe` and derive the installation directory from its location.
3. If auto-detection succeeds and the path is valid (jtestcli executable exists), use it silently.
4. **If auto-detection fails**: print `ERROR: JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry.` and terminate immediately.

#### Resolve `ANALYZED_PROJECT_PATH`

1. Read the `ANALYZED_PROJECT_PATH` environment variable.
2. **If not set or the path does not exist**: print `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` and terminate immediately.

#### Resolve `JTEST_UTA_CONFIGURATION`

1. Read the `JTEST_UTA_CONFIGURATION` environment variable.
2. If not set, use the default value `builtin://Create Unit Tests` silently — **do not prompt the user**.

#### Resolve `JTEST_COMMIT_FIXES`

1. Read the `JTEST_COMMIT_FIXES` environment variable.
2. Commits are performed only if the value is exactly `true` (case-insensitive). Any other value or absence means fixes are left as local uncommitted changes.

#### Resolve `JTEST_SETTINGS`

1. Read the `JTEST_SETTINGS` environment variable.
2. If `JTEST_SETTINGS` is set, verify that the file exists at the specified path. **If the file does not exist**: print 
`ERROR: JTEST_SETTINGS points to a file that does not exist: [path]. Verify the path and retry.` 
and terminate immediately.
3. If `JTEST_SETTINGS` is not set, omit the `-Djtest.settings` option from all analysis commands silently — **do not prompt the user**.

#### Resolve `JTEST_UTA_RESOURCE`

1. Read the `JTEST_UTA_RESOURCE` environment variable.
2. If `JTEST_UTA_RESOURCE` is not set omit the `-Djtest.resources` option from all analysis commands silently — **do not prompt the user**.

#### Resolve `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE`

1. Read the `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE` environment variables.
2. Verify if **both variables are set together or not set at all**. If only one is set, print the warning:
`WARN: For TIA mode both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE must be set together. ` 
These variables are used for TIA mode and if they are not set the skill will run in non-TIA mode. 
If only one of them is set, the skill will ignore it and run in non-TIA mode silently — **do not prompt the user**.

#### Resolve `JTEST_REFERENCE_BRANCH`
1. Read the `JTEST_REFERENCE_BRANCH` environment variable.
2. if `JTEST_REFERENCE_BRANCH` **is set do**:
 - verify if `ANALYZED_PROJECT_PATH` is a valid git repository. **If it is not a valid git repository**: print
`ERROR: ANALYZED_PROJECT_PATH is not a valid git repository. JTEST_REFERENCE_BRANCH cannot be used. Verify the ANALYZED_PROJECT_PATH and retry.`
 - verify that the branch exists in the git repository. **If the branch does not exist**: print
`ERROR: JTEST_REFERENCE_BRANCH is does not exist. Check the settings for JTEST_REFERENCE_BRANCH environment variable and retry.`
3. If `JTEST_REFERENCE_BRANCH` **is not set**, the skill will run analysis without branch comparison silently — **do not prompt the user**.

#### Resolve `GIT_WORKSPACE` and `GIT_BRANCH` if `JTEST_REFERENCE_BRANCH` is set
1. If `JTEST_REFERENCE_BRANCH` is set do:
 - read the `GIT_WORKSPACE` environment variable and verify that it points to an existing directory. **If it is not set or does not point to an existing directory**: print
`ERROR: GIT_WORKSPACE cannot be resolved automatically. Set it to the root directory of git repo for your project.`
 - read the `GIT_BRANCH` environment variable and verify that it is set. **If it is not set**: print
`ERROR: GIT_BRANCH cannot be resolved automatically. Set it to the current branch of git repo for your project.`


### Show Resolved Variables to User. This step is mandatory!

**After all variables have been resolved successfully, print a summary of all resolved values to the console before proceeding to Step 2. Use the following format exactly:**

```
Resolved configuration:
  JTEST_SKILLS_CONFIG      = [resolved value or "(not set)"]
  JTEST_HOME               = [resolved value]
  ANALYZED_PROJECT_PATH    = [resolved value]
  JTEST_UTA_CONFIGURATION  = [resolved value]
  JTEST_COMMIT_FIXES       = [resolved value or "false (default)"]
  JTEST_SETTINGS           = [resolved value or "(not set)"]
  JTEST_UTA_RESOURCE       = [resolved value or "(not set)"]
  JTEST_STATIC_BASE_REPORT = [resolved value or "(not set)"]
  JTEST_STATIC_BASE_COVERAGE = [resolved value or "(not set)"]
  JTEST_REFERENCE_BRANCH     = [resolved value or "(not set)"]
  GIT_WORKSPACE              = [resolved value or "(not set)"]
  GIT_BRANCH                 = [resolved value or "(not set)"]
```

**Print this block to stdout so the user can verify the effective settings before any analysis begins.**
**Do not execute any other steps until this block will be printed to stdout**

### Step 2: Verification

1. **Verify Jtest Installation**
   - Check if `JTEST_HOME` contains `jtestcli.exe` (Windows) or `jtestcli` (Linux/macOS).
   - Windows path: `[JTEST_HOME]\jtestcli.exe`
   - Linux/macOS path: `[JTEST_HOME]/jtestcli`
   - **If not found**: print `ERROR: jtestcli not found in JTEST_HOME=[JTEST_HOME]. Verify the Jtest installation path.` and terminate immediately.

2. **Detect Build System**
   - If `JTEST_UTA_SCRIPT_DIR` is not set, print the following error message:
   `ERROR: The build-verify scripts are not properly set at JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR].`
   and terminate immediately.
   - **Otherwise** detect the proper `build-verify` script and run it without any arguments:
         - Windows PowerShell (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.ps1"`
         - Windows (`.bat`): `[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.bat`
         - Linux/macOS: `bash "[JTEST_UTA_SCRIPT_DIR]/build-verify/build-verify.sh"`
   - **If the command fails (non-zero exit code)**: print `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` followed by the build output, **and terminate immediately unless other instructions are provided!** The preexisting tests failure are not accepted at this stage, unless there are special clear instructions to create tests despite the preexisting tests failure. 
   - If run is successful do not remember output from this run. 

### Step 3: Run UTA Test Creation

**If `JTEST_UTA_SCRIPT_DIR` is not set** — print 
`ERROR: The build scripts cannot be found in JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR].` 
and terminate immediately.
**otherwise do:**
- Check if the following variables are set: `JTEST_HOME`, `ANALYZED_PROJECT_PATH`, `JTEST_UTA_CONFIGURATION`, `JTEST_SETTINGS` `JTEST_UTA_RESOURCE`. 
- Detect the proper `jtest-analyze` script and run it:
   - Windows PowerShell (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_UTA_SCRIPT_DIR]\jtest-analyze\jtest-analyze.ps1"`
   - Windows (`.bat`): `[JTEST_UTA_SCRIPT_DIR]\jtest-analyze\jtest-analyze.bat`
   - Linux/macOS: `bash "[JTEST_UTA_SCRIPT_DIR]/jtest-analyze/jtest-analyze.sh"`

The script **must** exit with code `0` on success and a non-zero code on failure.

### Step 4: Prepare a List of Created Tests

1. At the end of tests creation run check if the file with tests creation status exist at **`ANALYZED_PROJECT_PATH`/target/jtest/.jtest/com.parasoft.xtest.testassist/fa_cli/session/status.json**.
2. **If file exist do:**
   - Parse the file and find a section `created_test_names`.
   - If section `created_test_names` exist validate each element in section `created_test_names` to match the pattern: `"<full_name_of_method_under_test_1>" : ["<full_name_of_test_1>", "<full_name_of_test_2>", ...]"`. The section `created_test_names` should looks as in example below:
      ```
         "created_test_names" : {
            "com.parasoft.parabank.web.form.AdminForm.setEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint()", com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint2(), "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint3()" ],
            "com.parasoft.parabank.web.form.AdminForm.setRestEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetRestEndpoint()" ],
            "com.parasoft.parabank.web.form.AdminForm.getParameters()" : [ ]
         }
      ```
   - Set an environmental variable `TEST_RESULTS`= **`ANALYZED_PROJECT_PATH`/target/jtest/.jtest/com.parasoft.xtest.testassist/fa_cli/session/status.json**.

3. **If `status.json` file does not exist OR IF section `created_test_names` is missed in `status.json` file OR IF validation of `created_test_names` fails do:**
   - Create a file at **`ANALYZED_PROJECT_PATH`/.jtest/status.json**.
   - Create a section `created_test_names` in **`ANALYZED_PROJECT_PATH`/.jtest/status.json** file.
   - Collect tests created during **THIS SESSION** and have in javadoc on the top of test method the following comment `"Parasoft Jtest UTA"`. **MAKE SURE TO COLLECT ONLY TESTS CREATED DURING THIS SESSION!** Do not include tests created in previous runs or manually created tests without mentioned comment in javadoc.
   - Group them by method under test. For each method under test identify all created tests that are testing this method.
   - Store in `created_test_names` section the data about creating tests in a form: 
      ```
      "<full_name_of_method_under_test_1>" : ["<full_name_of_test_1>", "<full_name_of_test_2>", ...]", 
      <full_name_of_method_under_test_2>" : ["<full_name_of_test_1>", "<full_name_of_test_2>", ...]"
      ```
      Example:
      ```
      {
         "created_test_names" : {
            "com.parasoft.parabank.web.form.AdminForm.setEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint()", com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint2(), "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint3()" ],
            "com.parasoft.parabank.web.form.AdminForm.setRestEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetRestEndpoint()" ],
            "com.parasoft.parabank.web.form.AdminForm.getParameters()" : [ ]
         }
      }
      ```
   - Double check if created tests are correctly grouped by its method under test and are stored in **`ANALYZED_PROJECT_PATH`/.jtest/status.json** as described in Step 4.1. **If it is not so provide necessary corrections**.
   - If no tests have been created leave `created_test_names` section empty. 
   - Set an environmental variable `TEST_RESULTS`= **`ANALYZED_PROJECT_PATH`/.jtest/status.json**.

   It is possible that the final number of created tests will be 0, even if the analysis output suggests that some tests have been created. This can happen if the created tests do not pass later verification step.

4. **Make sure the `TEST_RESULTS` environmental variable is set and provide to existing file. If not print the following error message: `ERROR: The summary about created tests does not exist at TEST_RESULTS=[TEST_RESULTS].`  and TERMINATE IMMEDIATELY!**


### Step 5: Prepare a Plain List of Created Tests
1. Check if environmental variable `TEST_RESULTS` exist and point to existing file. **If not print the following error message: `ERROR: The summary about created tests does not exist at TEST_RESULTS=[TEST_RESULTS].` and TERMINATE IMMEDIATELY!**.
2. Read the file from `TEST_RESULTS` and find the section `created_test_names` in it.
3. Parse the section `created_test_names` and extract tests methods from it to separate list `LIST_OF_CREATED_TESTS`. In order to simplify parsing consider the following  data format in `created_test_names` section:
      ```
      "<full_name_of_method_under_test_1>" : ["<full_name_of_test_1>", "<full_name_of_test_2>", ...]", 
      <full_name_of_method_under_test_2>" : ["<full_name_of_test_1>", "<full_name_of_test_2>", ...]"
      ```
      Example:
      ```
      {
         "created_test_names" : {
            "com.parasoft.parabank.web.form.AdminForm.setEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint()", com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint2(), "com.parasoft.parabank.web.form.AdminFormTest.testSetEndpoint3()" ],
            "com.parasoft.parabank.web.form.AdminForm.setRestEndpoint(String)" : [ "com.parasoft.parabank.web.form.AdminFormTest.testSetRestEndpoint()" ],
            "com.parasoft.parabank.web.form.AdminForm.getParameters()" : [ ]
         }
      }
      ```
   **The list of created tests `LIST_OF_CREATED_TESTS` should contains the tests from all methods under tests!**
4. Export the list of created tests `LIST_OF_CREATED_TESTS` as an environment variable for the next steps.


### Step 6: Run Existing Tests from project located at `ANALYZED_PROJECT_PATH`

1. **Verify unit tests are running** (compilation is performed implicitly as part of the test run)
   - **If `JTEST_UTA_SCRIPT_DIR` is set** — call the custom build-verify script:
     - Windows PowerShell (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.ps1"`
     - Windows (`.bat`): `[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.bat`
     - Linux/macOS: `bash "[JTEST_UTA_SCRIPT_DIR]/build-verify/build-verify.sh"`
     - The script receives the following environment variables automatically (they are already set): `ANALYZED_PROJECT_PATH`.
   - **Otherwise** (no `JTEST_UTA_SCRIPT_DIR`):
      - print the following error message:
         `ERROR: The build-verify scripts are not properly set at JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR].`
   - **Continue if the command fails (non-zero exit code) because of failing tests!**
2. Here if TIA mode is enabled then only limited number of tests will be executed. 


### Step 7: Prepare a List of Tests for Post-Processing 

1. Identify all tests that fails or ends with error on Step 6.
2. Create a list of failing tests and tests with error and put them into `FINAL_LIST_OF_TESTS_TO_PROCESS`. Each test in the list should contain:
   - Fully qualified test class name.
   - Test method name.
   - Failure reason (short summary from stack trace or test output).
3. **If THERE ARE NO special instructions from the user or previous steps about what tests should be fixed do:**
   - Remove from the list with failing tests or tests with errors `FINAL_LIST_OF_TESTS_TO_PROCESS` the tests that are not in a list of created tests prepared in previous step `LIST_OF_CREATED_TESTS`. **THIS IS DEFAULT CHOICE!**

   **Otherwise if THERE ARE special instructions from the user or previous steps about what tests should be fixed STRICTLY FOLLOW provided instructions to change the `FINAL_LIST_OF_TESTS_TO_PROCESS`. In the instructions should be clearly mentioned TO FIX OR REMOVE TESTS and WHICH ONES. IF IT IS NOT CLEAR FROM INSTRUCTIONS AND THEY CONTEXT WHAT TESTS TO FIX OR REMOVE -- DO DEFAULT CHOICE!**
   
   The possible instructions may be:
   - **"Fix all failing tests or tests with errors"** AND/OR **"Remove all failing tests or tests with errors"** -- then do not change the `FINAL_LIST_OF_TESTS_TO_PROCESS`;
   - **"Fix the failing tests from package `<package-name>`"** AND/OR **"Remove the failing tests from package `<package-name>`"** -- then from list `FINAL_LIST_OF_TESTS_TO_PROCESS` remove all tests **EXCEPT THE ONES** from package `<package-name>`;
   - **"Fix the failing tests that match the pattern `<pattern>`"** AND/OR **"Remove the failing tests that match the pattern `<pattern>`"**  -- then from list `FINAL_LIST_OF_TESTS_TO_PROCESS` remove all tests **EXCEPT THE ONES** that match the provided pattern `<pattern>`;
   - **Do not fix the failing tests or tests with errors** AND/OR **Do not remove the failing tests or tests with errors**  -- then **remove all** tests from `FINAL_LIST_OF_TESTS_TO_PROCESS` and keep it **EMPTY**.

4. Export the list of tests to fix `FINAL_LIST_OF_TESTS_TO_PROCESS` as an environment variable for the next steps and postprocessing phase. **If there are no tests to fix the list `FINAL_LIST_OF_TESTS_TO_PROCESS` should be empty!**
**Make sure the list `FINAL_LIST_OF_TESTS_TO_PROCESS` will be available in next subskills!**


### Step 8: Commit the Changes but only if `JTEST_COMMIT_FIXES=true`

**By default, do NOT commit any changes.** Skip this step unless `JTEST_COMMIT_FIXES` is set to exactly `true` (case-insensitive) in the environment.

**If `JTEST_COMMIT_FIXES=true`**: Stage only files created or modified during test generation (`git add <created-or-modified-files> ...`) and commit with a message in the format:

```
Add UTA generated tests. Co-authored-by: Coding Agent
```

**If `JTEST_COMMIT_FIXES=true` changes should be committed as instructed above. This is mandatory!**

**If `JTEST_COMMIT_FIXES` is not set or not `true`**: Leave the fixed files as uncommitted local changes and proceed to the summary.

### Step 9: Summary

After test creation completes, report:
- Test cases created
- Test classes created
- Methods tested with created test cases
- Name of configuration used for test creation

If `JTEST_COMMIT_FIXES=true` also report:
- Successful commits (if committing was requested)

If `JTEST_COMMIT_FIXES` is not `true`, also report:
- Files with uncommitted local changes (list all uncommitted files if committing was not requested)


## Error Handling

All errors are printed to the console (stderr) and cause immediate termination with a non-zero exit code. No user interaction is performed.

| Condition | Console message | Action |
| --------------------------------------------------------| -----------------------------------------------------------------------------------| -----------------------|
| `JTEST_SKILLS_CONFIG` file not found                    | `ERROR: JTEST_SKILLS_CONFIG points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_HOME` not set and jtestcli not on PATH           | `ERROR: JTEST_HOME is not set and jtestcli was not found on PATH. Set the JTEST_HOME environment variable and retry.` | Terminate immediately |
| `ANALYZED_PROJECT_PATH` not set or path does not exist  | `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` | Terminate immediately |
| jtestcli not found in `JTEST_HOME`                      | `ERROR: jtestcli not found in JTEST_HOME=[JTEST_HOME]. Verify the Jtest installation path.` | Terminate immediately |
| No supported build file found                           | `ERROR: No supported build file (pom.xml, build.gradle) found in ANALYZED_PROJECT_PATH=[ANALYZED_PROJECT_PATH]. Only Maven and Gradle projects are supported.` | Terminate immediately |
| Build or unit tests fail                                | `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` + build output | Terminate immediately |
| Test generation command returns non-zero                | `ERROR: Jtest-UTA test generation exited with code [N]. See output above for details.` | Terminate immediately |
| `JTEST_SETTINGS` file not found                         | `ERROR: JTEST_SETTINGS points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_UTA_SCRIPT_DIR` directory not found              | `ERROR: JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| Required script missing in `JTEST_UTA_SCRIPT_DIR`       | `ERROR: JTEST_UTA_SCRIPT_DIR=[path] is missing required script [script-name]. Provide correct path to "scripts" directory and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_REPORT` file not found               | `ERROR: JTEST_STATIC_BASE_REPORT points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_COVERAGE` file not found             | `ERROR: JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_REFERENCE_BRANCH` branch is not found           | `ERROR: JTEST_REFERENCE_BRANCH points to a branch that does not exist: [branch]. Verify the branch and retry.` | Terminate immediately |
| `JTEST_REFERENCE_BRANCH` but no git repository         | `ERROR: ANALYZED_PROJECT_PATH is not a valid git repository. JTEST_REFERENCE_BRANCH cannot be used. Verify the ANALYZED_PROJECT_PATH and retry.` | Terminate immediately |
| `GIT_WORKSPACE` not set or path does not exist         | `ERROR: GIT_WORKSPACE cannot be resolved automatically. Set it to the root directory of git repo for your project.` | Terminate immediately |
| `GIT_BRANCH` not set                                   | `ERROR: GIT_BRANCH cannot be resolved automatically. Set it to the current branch of git repo for your project.` | Terminate immediately |

## Custom Script Mode

When `JTEST_UTA_SCRIPT_DIR` is set the skill delegates all build and analysis operations to user-supplied scripts found in that directory. This is the recommended approach for complex projects that require custom Maven/Gradle arguments, multi-module builds, special environment setup, or non-standard Jtest configurations.

### Required Scripts

| Script purpose                       | Windows (`.bat` preferred, `.ps1` fallback) | Linux/macOS        |
|--------------------------------------|---------------------------------------------| -------------------|
| Build the project and run unit tests | `build-verify.bat` / `build-verify.ps1`     | `build-verify.sh`  |
| Run UTA tests generation             | `jtest-analyze.bat` / `jtest-analyze.ps1`   | `jtest-analyze.sh` |


Template scripts are provided in the `scripts/` subdirectory next to this `SKILL.md` file in `build-verify` and `jtest-analyze` subdirectories respectively. Copy them into your project or a dedicated directory, customize them, and point `JTEST_UTA_SCRIPT_DIR` at that directory.

### Environment Variables Available to Scripts

The skill guarantees that the following environment variables are set before calling this script:

| Variable                   | Guaranteed value                                        |
|----------------------------|---------------------------------------------------------|
| `JTEST_HOME`               | Resolved Jtest installation path                        |
| `ANALYZED_PROJECT_PATH`    | Resolved project root path                              |
| `JTEST_UTA_CONFIGURATION`  | Resolved test configuration (never empty)               |
| `JTEST_COMMIT_FIXES`       | Resolved commit fixes setting (true or false but never empty) |
| `JTEST_UTA_SCRIPT_DIR`     | Resolved script directory path (never empty)            |

### Script Contract

**`build-verify` script**:
- Must build the project and run all unit tests.
- Must exit with code `0` on success, non-zero on any failure.
- May print any output to stdout/stderr; it is captured and shown on failure.

**`jtest-analyze` script**:
- Must run a test configuration given by `JTEST_UTA_CONFIGURATION` or default one. 
- The run should be invoked via `jtestcli` or the Maven/Gradle Jtest plugin.
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

This subskill includes:
- Automated test creation
- Git-based change tracking and rollback
