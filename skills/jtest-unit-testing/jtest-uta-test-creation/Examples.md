# Examples to learn

## Example 1: Basic Analysis (Maven, Windows)

```powershell
$env:JTEST_HOME    = "C:\Parasoft\jtest"
$env:PROJECT_PATH  = "C:\projects\myapp"
# JTEST_TEST_CONFIGURATION defaults to "builtin://Create Unit Tests"

# Skill output (no prompts):
# Verifying Jtest installation... [OK]
# Detecting build system... Found pom.xml (Maven)
# Compiling project... [OK]
# Running: mvnw.cmd jtest:jtest -Djtest.config="builtin://Create Unit Tests"
# Test generation finished
```

## Example 2: Gradle Project with Custom Config and Commit (Linux/macOS)

```bash
export JTEST_HOME="/opt/parasoft/jtest"
export PROJECT_PATH="/home/user/myapp"
export JTEST_TEST_CONFIGURATION="builtin://Create Unit Tests"
export JTEST_COMMIT_FIXES="true"

# Skill output (no prompts):
# Verifying Jtest installation... [OK]
# Detecting build system... Found build.gradle (Gradle)
# Compiling project... [OK]
# Running: ./gradlew jtest -I/opt/parasoft/jtest/integration/gradle/init.gradle \
#          -Djtest.config="builtin://Create Unit Tests"
# Test generation finished
```

## Example 3: Missing Required Variable (non-zero exit)

```powershell
# JTEST_HOME is not set

# Skill output:
# ERROR: JTEST_HOME is not set or does not point to an existing directory.
#        Set the JTEST_HOME environment variable and retry.
# Exit code: 1
```

## Example 4: Complex Project with Custom Scripts (Windows)

```powershell
$env:JTEST_HOME    = "C:\Parasoft\jtest"
$env:PROJECT_PATH  = "C:\projects\complex-app"
$env:SCRIPT_DIR    = "C:\projects\complex-app\.jtest-scripts"
$env:JTEST_COMMIT_FIXES = "true"

# Skill output (no prompts):
# Verifying Jtest installation... [OK]
# SCRIPT_DIR is set — skipping build-system detection.
# Running build-verify script: C:\projects\complex-app\.jtest-scripts\build-verify.bat
# Build and tests passed. [OK]
# Running jtest-analyze script: C:\projects\complex-app\.jtest-scripts\jtest-analyze.bat
# Test generation finished
# Fixing and committing violations...
```

## Example 5: Using a Config File (Windows)

```powershell
# All settings are stored in a config file — only one env var needed
$env:JTEST_SKILL_CONFIG = "C:\projects\myapp\skill.config"

# Contents of skill.config:
#   JTEST_HOME=C:\Parasoft\jtest
#   PROJECT_PATH=C:\projects\myapp
#   JTEST_TEST_CONFIGURATION=builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES=true

# Skill output (no prompts):
# Resolved configuration:
#   JTEST_SKILL_CONFIG       = C:\projects\myapp\skill.config
#   JTEST_HOME               = C:\Parasoft\jtest
#   PROJECT_PATH             = C:\projects\myapp
#   JTEST_TEST_CONFIGURATION = builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES       = true
#   ...
# Verifying Jtest installation... [OK]
# Detecting build system... Found pom.xml (Maven)
# Running: mvnw.cmd jtest:jtest -Djtest.config="builtin://Create Unit Tests"
# Test generation finished
```

## Example 6: Using a limited scope if JTEST_SCOPE_TO_TEST is set

```powershell
# All settings are stored in a config file — only one env var needed
$env:JTEST_SKILL_CONFIG = "C:\projects\myapp\skill.config"

# Contents of skill.config:
#   JTEST_HOME=C:\Parasoft\jtest
#   PROJECT_PATH=C:\projects\myapp
#   JTEST_TEST_CONFIGURATION=builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES=false
#   JTEST_SCOPE_TO_TEST=**/MetricsExample.java


# Skill output (no prompts):
# Resolved configuration:
#   JTEST_SKILL_CONFIG       = C:\projects\myapp\skill.config
#   JTEST_HOME               = C:\Parasoft\jtest
#   PROJECT_PATH             = C:\projects\myapp
#   JTEST_TEST_CONFIGURATION = builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES       = false
#   JTEST_SCOPE_TO_TEST      = **/MetricsExample.java
#   ...
# Verifying Jtest installation... [OK]
# Detecting build system... Found pom.xml (Maven)
# Running: mvnw.cmd jtest:jtest -Djtest.config="builtin://Create Unit Tests" -Djtest.resources=**/MetricsExample.java
# Test generation finished
```

## Example 7: Using a limited scope if JTEST_SCOPE_TO_TEST is set

```powershell
# All settings are stored in a config file — only one env var needed
$env:JTEST_SKILL_CONFIG = "C:\projects\myapp\skill.config"

# Contents of skill.config:
#   JTEST_HOME=C:\Parasoft\jtest
#   PROJECT_PATH=C:\projects\myapp
#   JTEST_TEST_CONFIGURATION=builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES=true
#   JTEST_SCOPE_TO_TEST=**/flowanalysis/**


# Skill output (no prompts):
# Resolved configuration:
#   JTEST_SKILL_CONFIG       = C:\projects\myapp\skill.config
#   JTEST_HOME               = C:\Parasoft\jtest
#   PROJECT_PATH             = C:\projects\myapp
#   JTEST_TEST_CONFIGURATION = builtin://Create Unit Tests
#   JTEST_COMMIT_FIXES       = true
#   JTEST_SCOPE_TO_TEST      = **/flowanalysis/**
#   ...
# Verifying Jtest installation... [OK]
# Detecting build system... Found pom.xml (Maven)
# Running: mvnw.cmd jtest:jtest -Djtest.config="builtin://Create Unit Tests" -Djtest.resources=**/flowanalysis/**
# Test generation finished
```
