---
name: jtest-uta-test-fixing
description: Provide Parasoft UTA Test Post-Processing on Java projects with generated tests, detect failed tests, and provide fixes to make them run. Use this skill as a post stage after `jtest-uta-test-creation` subskill is applied.
labels:
   - java
   - code-quality
   - jtest
   - parasoft
   - bulk creation quick fixes
   - UTA Post Processing
   - coverage
metadata:
   author: Parasoft
   version: "2.6"
   mode: non-interactive
   requires:
      - Parasoft Jtest installation
      - Maven or Gradle project
---

# UTA Tests Fixing Skill

## Overview

This skill enables agents to provide Parasoft UTA Test Post-Processing on Java projects with generated tests by UTA, and fix failing tests in a post-creation stage.

> **Non-interactive / nightly mode**: This skill operates fully autonomously. It **never** prompts the user for input. All required settings must be provided via environmental variables or in `.config` file before skill is invoked.. If a required setting cannot be determined automatically, the skill prints a descriptive error message to the console and terminates immediately with a non-zero exit code.

## When to Use This Skill

Use this skill when:
- It is referred from `jtest-unit-testing` skill.
- User mentions improve failing tests, fix failing test, increase coverage, improve maintainability of the project.


## Prerequisites

All settings are read from environment variables or provided by parent super skill or previous steps. No interactive prompts are issued.
**The following variables must be set before invoking the skill:**


| Variable                     | Required     | Description                                                                                                                     |
|------------------------------|--------------| --------------------------------------------------------------------------------------------------------------------------------|
| `JTEST_SKILLS_CONFIG`        | Optional     | Absolute path to a properties file (`key=value` format) from which all other settings below can be loaded. Environment variables always take precedence over values defined in this file. |
| `ANALYZED_PROJECT_PATH`      | **Required** | Absolute path to the Java project root to analyze. |
| `JTEST_COMMIT_FIXES`         | Optional     | Set to `true` to commit each successful fix. Any other value or absence means fixes are left as local uncommitted changes. |
| `JTEST_UTA_SCRIPT_DIR`       | Optional     | Absolute path to a directory containing custom build/analysis scripts. When set, the skill calls the scripts in this directory instead of invoking Maven/Gradle directly. |
| `JTEST_FIX_ATTEMPTS`         | Optional     | Number of additional attempts made to fix the test. **Set it to 0 if not set.** |
| `JTEST_UTA_NO_OF_MAX_FIXES`  | Optional     | Maximum number of fixes to attempt. **Set it to 0 if not set.** |
| `JTEST_STATIC_BASE_REPORT`   | Optional     | Absolute path to a base `report.xml` file. |
| `JTEST_STATIC_BASE_COVERAGE` | Optional     | Absolute path to a base `coverage.xml` file. |


## Critical Constraints

**If `JTEST_COMMIT_FIXES=true` - then fixed or modified tests must be committed in their own separate git commit.**

**No user interaction is permitted at any point. All values must come from environment variables, the config file, or be auto-detected. If a required value cannot be determined, print a clear error message to the console and terminate immediately with a non-zero exit code.**

**DO NOT DISABLE, SUPPRESS OR IGNORE THE TEST THAT FAILS!**. 
**DO NOT FIX TEST BY USING assertThrows IF EXCEPTION IS THROWN! TRY TO FIX THE ROOT CAUSE OF EXCEPTION BY ADDITIONAL MOCKING, OBJECT CREATING IN TESTS AND OTHER SUITABLE ACTIONS THAT WILL IMPROVE THE QUALITY OF TEST!**

## IMPORTANT INSTRUCTIONS TO FOLLOW:
1. Strictly implement each step one by one, consequently. 
2. After successful implementation of the step briefly report the result form the step.
3. Treat variables in Prerequisites as global ones.
4. **DO NOT CHANGE THE VARIABLES FROM Prerequisites! THEY ARE FINAL!**
5. USE RESULTS FROM PREVIOUS STEP IN NEXT STEP.

## How This Skill Works

### Step 1: Resolve Required Settings from Environment

#### Resolve `ANALYZED_PROJECT_PATH`

1. Read the `ANALYZED_PROJECT_PATH` environment variable.
2. **If not set or the path does not exist**: print `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` and terminate immediately.

#### Resolve `JTEST_COMMIT_FIXES`

1. Read the `JTEST_COMMIT_FIXES` environment variable.
2. Commits are performed only if the value is exactly `true` (case-insensitive). Any other value or absence means fixes are left as local uncommitted changes.

#### Resolve `JTEST_UTA_SCRIPT_DIR`

1. Read the `JTEST_UTA_SCRIPT_DIR` environment variable.
2. If set, verify that the directory exists. **If the directory does not exist**: print `ERROR: JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: [path]. Verify the path and retry.` and terminate immediately.
3. Verify that required script files are present inside `JTEST_UTA_SCRIPT_DIR`:
   - Windows: `build-verify\build-verify.bat` (or `build-verify\build-verify.ps1` for Windows PowerShell);
   - Linux/macOS: `build-verify/build-verify.sh`;
   - The `.bat` / `.ps1` / `.sh` variants are checked in that priority order; the first match for each script is used.
   - **If required script is missing**: print `ERROR: JTEST_UTA_SCRIPT_DIR=[path] is missing required script [script-name]. Provide build-verify script and retry.` and terminate immediately.

#### Resolve `JTEST_FIX_ATTEMPTS`
1. Read the `JTEST_FIX_ATTEMPTS` environment variable.
2. Check if is set to integer number. **If not set at all or is not set to integer number set it to 0 and print this warning:**
`WARNING: JTEST_FIX_ATTEMPTS is not properly set. The default value will be used.`

#### Resolve `JTEST_UTA_NO_OF_MAX_FIXES`
1. Read the `JTEST_UTA_NO_OF_MAX_FIXES` environment variable.
2. Check if is set to integer number. **If not set at all or is not set to integer number set it to 0 and print this warning:**
`WARNING: JTEST_UTA_NO_OF_MAX_FIXES is not properly set. The default value will be used.`

#### Resolve `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE`

1. Read the `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE` environment variables.
2. Verify if **both variables are set together or not set at all**. If only one is set, print the warning:
`WARN: For TIA mode both JTEST_STATIC_BASE_REPORT and JTEST_STATIC_BASE_COVERAGE must be set together. ` 
These variables are used for TIA mode and if they are not set the skill will run in non-TIA mode. 
If only one of them is set, the skill will ignore it and run in non-TIA mode silently — **do not prompt the user**.

#### Print Resolved Variables

After all variables have been resolved successfully, print a summary of all resolved values to the console before proceeding to Step 2. Use the following format exactly:

```
Resolved configuration:
  JTEST_SKILLS_CONFIG       = [resolved value or "(not set)"]
  ANALYZED_PROJECT_PATH     = [resolved value]
  JTEST_COMMIT_FIXES        = [resolved value or "false (default)"]
  JTEST_FIX_ATTEMPTS        = [resolved value or "0 (default)"]
  JTEST_UTA_NO_OF_MAX_FIXES = [resolved value or "0 (default)"]
  JTEST_STATIC_BASE_REPORT  = [resolved value or "(not set)"]
  JTEST_STATIC_BASE_COVERAGE = [resolved value or "(not set)"]
```

### Step 2: Identify Failing Tests And Tests With Error In Order To Fix Them

1. Check if list `FINAL_LIST_OF_TESTS_TO_PROCESS` is set as environmental variable and is available. 
**If `FINAL_LIST_OF_TESTS_TO_PROCESS` IS NOT SET as an environmental variable, then do:**
   -  **Check if there are** instructions from user or from previous steps about what tests should be fixed and fill `FINAL_LIST_OF_TESTS_TO_PROCESS` **strictly** follows that instructions.
   -  **If there ARE NO** special instructions about what tests should be fixed then prepare `FINAL_LIST_OF_TESTS_TO_PROCESS` with failing tests and tests with error as follow:
      - **If `JTEST_UTA_SCRIPT_DIR` is set** — call the custom build-verify script:
         - Windows (`.bat`): `[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.bat`
         - Windows (`.ps1`): `powershell -ExecutionPolicy Bypass -File "[JTEST_UTA_SCRIPT_DIR]\build-verify\build-verify.ps1"`
         - Linux/macOS: `bash "[JTEST_UTA_SCRIPT_DIR]/build-verify/build-verify.sh"`
         - The script receives the following environment variables automatically (they are already set): `ANALYZED_PROJECT_PATH`.
         - The script **must** exit with code `0` on success and a non-zero code on failure.
      - **Otherwise** (no `JTEST_UTA_SCRIPT_DIR`):
         - print the following error message **and terminate immediately**:
            `ERROR: The build-verify scripts are not properly set at JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR].`
   - **Continue if the command fails (non-zero exit code) because of failing tests!**
   - If build-verify scripts run is finished identify all failing tests or tests with error and populate `FINAL_LIST_OF_TESTS_TO_PROCESS` with those tests for further processing. Each test in the list should contain:
      - Fully qualified test class name.
      - Test method name.
      - Failure reason (short summary from stack trace or test output).
      
**If there are no failing tests and no tests with error, then `FINAL_LIST_OF_TESTS_TO_PROCESS` should be empty.**

**Keep in mind that `FINAL_LIST_OF_TESTS_TO_PROCESS` MAY BE EMPTY!**
2. Create an empty list `FIXED_TESTS`.
3. Iterate over a list of failing tests and tests with error `FINAL_LIST_OF_TESTS_TO_PROCESS` and for each test do:
   1. Pick up a single failing test or test with error and determine the failing reason by analyzing:
      - **test method and its context**,
      - **test class and its context**,
      - **its stack trace**,
      - **test output**,
      - **test resources**, 
      - **class under test and its context**,
      - **hierarchy of class under test (its abstract classes, interfaces etc.) and their context**
      - **method under test and its context**. 
   2. Apply necessary changes to failing test in order to make it pass. Do **ANY SUITABLE** changes within **test method** and/or **test class** to improve test quality and make it test pass.
   **DO NOT DISABLE, SUPPRESS OR IGNORE THE TEST THAT FAIL!**. 
   **DO NOT FIX TEST BY USING assertThrows IF EXCEPTION IS THROWN! TRY TO FIX THE ROOT CAUSE OF EXCEPTION BY ADDITIONAL MOCKING, OBJECT CREATING IN TESTS AND OTHER SUITABLE ACTIONS THAT WILL IMPROVE THE QUALITY OF TEST!**
   **DO NOT DELETE ANY TESTS AT THIS STAGE**. 
   **DO NOT BREAK COMPILATION OF THE CLASS THAT YOU MODIFY**

   3. Run a fixed test strictly in the following way:
      - **If `JTEST_UTA_SCRIPT_DIR` is set do:**
         - call the custom build-verify script **with argument `TestClassNameTest`**, where `TestClassNameTest` is name of test class where fixed test is located.
      - **Otherwise** (no `JTEST_UTA_SCRIPT_DIR`):
         - print the following error message:
            `ERROR: The build-verify scripts are not properly set at JTEST_UTA_SCRIPT_DIR=[JTEST_UTA_SCRIPT_DIR].`
   4. Find and check if the fixed test pass. **If test pass add it to the list of fixed tests `FIXED_TESTS`.** 
   5. If fixed test still fail make `JTEST_FIX_ATTEMPTS` more attempts to fix it: repeat steps from 3.3.1 to 3.3.5 `JTEST_FIX_ATTEMPTS` times for the test that fail.
   6. If test with fix still fail after `JTEST_FIX_ATTEMPTS` provided attempts revert the fix.
   7. If the value of `JTEST_UTA_NO_OF_MAX_FIXES` is more than 0 and the total number of attempted fixes has reached or exceeded `JTEST_UTA_NO_OF_MAX_FIXES`, then stop fixing tests and proceed to Step 4. Provide a warning message in the console:
      `WARNING: The maximum number of fixes (JTEST_UTA_NO_OF_MAX_FIXES=[JTEST_UTA_NO_OF_MAX_FIXES]) has been reached. Stopping further attempts to fix tests.`
   

**IMPORTANT NOTES!**
- **Do not change production code under test!**
- **DO NOT PROCESS THE TEST THAT HAS BEEN PROCESSED** 

### Step 3: Handle Remaining Failing Tests
1. Remove from the list `FINAL_LIST_OF_TESTS_TO_PROCESS` all tests that are in the list of fixed tests `FIXED_TESTS`.
2. Export the updated list of tests for further processing `FINAL_LIST_OF_TESTS_TO_PROCESS` as an environment variable for the next steps and postprocessing phases.

### Step 4: Commit the Changes but only if `JTEST_COMMIT_FIXES=true`

**By default, do NOT commit any changes.** Skip this step unless `JTEST_COMMIT_FIXES` is set to exactly `true` (case-insensitive) in the environment.


**If `JTEST_COMMIT_FIXES=true`**: Stage only the test files modified in this subskill during fixing test cases (`git add <modified-test-files> ...`) and commit with a message in the format:

```
Add UTA fixed tests. Co-authored-by: Coding Agent
```

**If `JTEST_COMMIT_FIXES=true` changes should be committed as instructed above. This is mandatory!**

**If `JTEST_COMMIT_FIXES` is not set or not `true`**: Leave the fixed files as uncommitted local changes and proceed to the summary.

### Step 5: Summary

Report:
- Total applied fixes
- List of tests **that have been FIXED** in format `TestClassTest#testMethod`

If `JTEST_COMMIT_FIXES=true` also report:
- Successful commits (if committing was requested)

If `JTEST_COMMIT_FIXES` is not `true`, also report:
- Files with uncommitted local changes (list all uncommitted files if committing was not requested)


## Error Handling

All errors are printed to the console (stderr) and cause immediate termination with a non-zero exit code. No user interaction is performed.

| Condition                                              | Console message                                                                                       | Action                    |
| -------------------------------------------------------| ------------------------------------------------------------------------------------------------------| --------------------------|
| `JTEST_SKILLS_CONFIG` file not found                   | `ERROR: JTEST_SKILLS_CONFIG points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `ANALYZED_PROJECT_PATH` not set or path does not exist | `ERROR: ANALYZED_PROJECT_PATH is not set or does not point to an existing directory. Set the ANALYZED_PROJECT_PATH environment variable and retry.` | Terminate immediately |
| No supported build file found                          | `ERROR: No supported build file (pom.xml, build.gradle) found in ANALYZED_PROJECT_PATH=[ANALYZED_PROJECT_PATH]. Only Maven and Gradle projects are supported.` | Terminate immediately |
| Build or unit tests fail                               | `ERROR: Project build or unit tests failed. Fix compilation errors or failing tests before running analysis.` + build output | Terminate immediately |
| `JTEST_UTA_SCRIPT_DIR` directory not found             | `ERROR: JTEST_UTA_SCRIPT_DIR points to a directory that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| Required script missing in `JTEST_UTA_SCRIPT_DIR`      | `ERROR: JTEST_UTA_SCRIPT_DIR=[path] is missing required script [script-name]. Provide correct path to "scripts" directory and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_REPORT` file not found              | `ERROR: JTEST_STATIC_BASE_REPORT points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |
| `JTEST_STATIC_BASE_COVERAGE` file not found            | `ERROR: JTEST_STATIC_BASE_COVERAGE points to a file that does not exist: [path]. Verify the path and retry.` | Terminate immediately |


## Implementation Details

### Build System Detection Logic

1. Check for `pom.xml` in project root => Maven
2. Check for `build.gradle` or `build.gradle.kts` => Gradle
3. If neither found => Error: Unsupported build system

### Exit Code Interpretation

- `0`: Success - analysis completed
- `Non-zero`: Error occurred or violations exceeded threshold

## Advanced Features

This skill includes:
- Automated test fixing in case of fails
- Intelligent test fix generation and application
- Comprehensive verification (unit tests after each fix)
- Git-based change tracking and rollback
