## Script Execution Mode

All Maven and Gradle invocations are always performed through two scripts located in `JTEST_STATIC_SCRIPT_DIR`. The default scripts in `<skill_dir>/scripts/` handle Maven and Gradle project auto-detection out of the box. Override `JTEST_STATIC_SCRIPT_DIR` to supply project-specific scripts for complex or non-standard builds.

### Required Scripts

| Script purpose | Windows (`.bat` preferred, `.ps1` fallback) | Linux/macOS |
|---|---|---|
| Resolve and validate configuration | `internal\resolve-config.bat` / `internal\resolve-config.ps1` | `internal/resolve-config.sh` |
| Dispatch helper for workflow scripts | `internal\run-script.bat` / `internal\run-script.ps1` | `internal/run-script.sh` |
| Build the project and run unit tests | `build-verify\build-verify.bat` / `build-verify\build-verify.ps1` | `build-verify/build-verify.sh` |
| Run Jtest static analysis | `jtest-analyze\jtest-analyze.bat` / `jtest-analyze\jtest-analyze.ps1` | `jtest-analyze/jtest-analyze.sh` |

The default scripts are located in the `scripts/build-verify/` and `scripts/jtest-analyze/` subdirectories next to this `SKILL.md`. To customise for a specific project, copy the scripts to a project directory, modify them, and set `JTEST_STATIC_SCRIPT_DIR` to that directory.

### Environment Variables Available to Scripts

The skill guarantees that the following environment variables are set before calling either script:

| Variable                     | Guaranteed value |
|------------------------------|---|
| `JTEST_HOME`                 | Resolved Jtest installation path |
| `ANALYZED_PROJECT_PATH`      | Resolved project root path |
| `JTEST_STATIC_CONFIGURATION` | Resolved test configuration (never empty) |
| `JTEST_SETTINGS`             | Absolute path to settings file, or empty string if not set |
| `JTEST_STATIC_BASE_REPORT`   | Absolute path to the base `report.xml` file, or empty string if not set |
| `JTEST_STATIC_BASE_COVERAGE` | Absolute path to the base `coverage.xml` file, or empty string if not set |
| `JTEST_REF_REPORT_FILE`      | Absolute path to the baseline `report.xml` for fix-verification runs; empty string during the initial analysis in Step 3 |
| `JTEST_REF_REPORT_EXCLUDE`   | `false` during fix-verification runs (Step 6); empty string during the initial analysis in Step 3 |
| `JTEST_RESOURCE`             | Comma-separated list of resource patterns to restrict analysis scope (e.g. `**/com/foo/**` or `**/ABC.java`). During the **initial analysis (Step 3)**: set to the scope patterns derived from the user's request (if any); empty string for full-project analysis. During **fix-verification runs (Step 6)**: set to the changed file(s) only. Scripts must split on commas and pass each value as a separate `-Djtest.resource` switch. |

### Script Contract

**`build-verify` script**:
- Must build the project and run unit tests.
- When both `JTEST_STATIC_BASE_REPORT` and `JTEST_STATIC_BASE_COVERAGE` are set, must run only the tests affected by changes (TIA mode) using the appropriate Maven goal (`tia:affected-tests test`) or Gradle task (`affectedTests test`) with the reference file arguments. Otherwise, must run all tests.
- Must exit with code `0` on success, non-zero on any failure.
- May print any output to stdout/stderr; it is captured and shown on failure.

**`jtest-analyze` script**:
- Must invoke Jtest analysis via the Maven/Gradle Jtest plugin.
- Must split `JTEST_RESOURCE` on commas and pass each pattern as a separate `-Djtest.resource` switch (omit all `-Djtest.resource` switches when `JTEST_RESOURCE` is empty).
- When `JTEST_REF_REPORT_FILE` is set, must include `-Dproperty.goal.ref.report.file` and `-Dproperty.goal.ref.report.findings.exclude` in the analysis command.
- Must exit with code `0` on success, non-zero on any failure.
- Must always print the report path to stdout on its **last line** in the form `REPORT_XML=[absolute-path]` on success.
