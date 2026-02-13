# Test Suite for Home Assistant Scripts

## Overview

This directory contains comprehensive pytest tests for the Home Assistant utility scripts.

## Test Coverage

- **test_hass_util.py** - Tests for `hass_util.py`
  - Environment file loading
  - Configuration management
  - WebSocket API interactions
  - Area and label fetching
  - Table printing utilities
  - CLI argument parsing

- **test_gen_presence_sensors.py** - Tests for `gen_presence_sensors.py`
  - Sensor dictionary creation
  - Label-based area exclusion
  - Jinja2 template rendering
  - YAML file generation
  - Home Assistant API uploads
  - Full integration flows

## Setup

Install test dependencies:

```bash
pip install -r test/requirements.txt
```

## Running Tests

### Interactive Test Menu (Recommended)

The `testmenu.sh` script provides an interactive whiptail-based menu for running tests:

```bash
cd test
./testmenu.sh
```

**Features:**
- ✅ Interactive checklist selection (whiptail/dialog or text fallback)
- ✅ Run all tests, individual test files, or coverage runs
- ✅ Automatically uses `-vv -s` for full verbose output and print statements
- ✅ Supports `-test` flag (dry-run) and `--debug` flag (diagnostic output)
- ✅ Integrated logging via `scripts/util/logging.sh`

**Flags:**
```bash
./testmenu.sh --test    # Dry-run mode (shows commands without execution)
./testmenu.sh --debug   # Debug mode (shows script paths and variables)
```

**Menu Options:**
- **Run All Tests** - Executes entire test suite with verbose output
- **File: test_hass_util.py** - Run only hass_util tests
- **File: test_gen_presence_sensors.py** - Run only presence sensor tests
- **Coverage (all)** - Run all tests with coverage report

### Command-Line Test Execution

### Run all tests
```bash
pytest
```

### Run with coverage report
```bash
pytest --cov=hass_util --cov=gen_presence_sensors --cov-report=term-missing
```

### Run specific test file
```bash
pytest test/test_hass_util.py
pytest test/test_gen_presence_sensors.py
```

### Run specific test class
```bash
pytest test/test_hass_util.py::TestSlugify
```

### Run specific test
```bash
pytest test/test_hass_util.py::TestSlugify::test_slugify_basic
```

### Run with verbose output
```bash
pytest -v
```

### Run with debug output
```bash
pytest -s
```

### Print every test name and its output
To list every test (including nested classes) and also show any print/log/debug output produced by the tests in real time, combine verbosity with no-output-capture:
```bash
pytest -vv -s
```

This will:
- Display each test node ID (file::Class::test_function)
- Stream all print/logging output immediately (helpful for diagnosing hangs)
- Show assertion diffs inline

### Full detail (names, timings, durations, failures first)
```bash
pytest -vv -s --durations=0 --maxfail=1
```
Explanation:
- `-vv` ultra-verbose (each test fully listed)
- `-s` do not capture stdout/stderr
- `--durations=0` show duration for every test (useful to spot slow ones)
- `--maxfail=1` stop on first failure while still printing preceding tests

### Print only failing test stdout (keep capture for passing tests)
If you want every test name printed but only see output for failures, omit `-s`:
```bash
pytest -vv
```
This still lists all tests but captures their output (cleaner fast pass runs).

### Generate verbose coverage with full test listing
```bash
pytest -vv --cov=hass_util --cov=gen_presence_sensors --cov-report=term-missing
```

### Continuous watch (rerun on changes) with full output (requires pytest-watch)
```bash
ptw -vv -s
```
Install first if needed:
```bash
pip install pytest-watch
```

### Quickly grep for a subset while printing all executed test names
```bash
pytest -vv -k hass_util -s
```
Where `-k <expr>` filters to matching test names while still enumerating each executed test.

## Test Structure

Tests follow the Arrange-Act-Assert pattern:

```python
def test_example():
    # Arrange - Setup test data and mocks
    test_data = [...]
    
    # Act - Execute the function being tested
    result = function_under_test(test_data)
    
    # Assert - Verify expected outcomes
    assert result == expected_value
```

## Fixtures

Common fixtures are defined in `conftest.py`:

- `temp_env_file` - Temporary environment file
- `mock_env` - Clean environment for testing
- `sample_areas` - Sample Home Assistant area data
- `sample_labels` - Sample Home Assistant label data
- `mock_websocket` - Mocked websocket connection
- `temp_template_dir` - Temporary Jinja2 templates
- `temp_packages_dir` - Temporary output directory

## Coverage Goals

Target: 80%+ coverage for both modules

Generate HTML coverage report:
```bash
pytest --cov-report=html:test/htmlcov
open test/htmlcov/index.html
```

## Continuous Integration

These tests can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Run tests
  run: |
    pip install -r scripts/hass/test/requirements.txt
    cd scripts/hass
    pytest
```

## Testing Best Practices

1. **Isolation** - Each test is independent and doesn't affect others
2. **Mocking** - External dependencies (API calls, file I/O) are mocked
3. **Coverage** - Aim for high coverage but focus on meaningful tests
4. **Naming** - Test names clearly describe what they test
5. **Speed** - Tests run quickly; slow tests marked with `@pytest.mark.slow`

## Troubleshooting

### Import Errors
Ensure parent directory is in Python path (handled in test files):
```python
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
```

### Async Test Failures
Ensure pytest-asyncio is installed and tests are marked:
```python
@pytest.mark.asyncio
async def test_async_function():
    ...
```

### Mock Issues
Verify mock patches target the correct import path:
```python
# Bad: patches original module
with patch('websockets.connect'):

# Good: patches where it's imported
with patch('hass_util.websockets.connect'):
```
