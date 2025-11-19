# Testing Guide for dthostmon

**Last Updated:** November 15, 2025

This document provides comprehensive guidance on testing dthostmon, including running tests locally, creating new tests, and understanding the CI/CD pipeline.

## Table of Contents

1. [Test Suite Overview](#test-suite-overview)
2. [Running Tests Locally](#running-tests-locally)
3. [Python Virtual Environment Setup](#python-virtual-environment-setup)
4. [Docker-Based Testing](#docker-based-testing)
5. [Creating New Tests](#creating-new-tests)
6. [Test Fixtures and Mocking](#test-fixtures-and-mocking)
7. [Coverage Requirements](#coverage-requirements)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Debugging Test Failures](#debugging-test-failures)

## Test Suite Overview

The dthostmon test suite is organized into two main categories:

### Unit Tests (`tests/unit/`)
- **Purpose:** Test individual components in isolation
- **Speed:** Fast (< 1 second each)
- **Dependencies:** Mocked external services
- **Coverage Target:** 90% for critical modules

**Existing Unit Test Files:**
- ✅ `test_config.py` - Configuration loading and parsing - 179 lines, 19 tests (Session 10: Added 8 new tests for hierarchical config)
- ✅ `test_database.py` - Database models and relationships
- ✅ `test_ai_analyzer.py` - AI analysis logic (mocked APIs)
- ✅ `test_ssh_client.py` - SSH connection handling (mocked) - 420 lines, 25 tests
- ✅ `test_email_alert.py` - Email generation and sending (mocked) - 801 lines, 38 tests (Session 10: Added 10 report delivery tests)
- ✅ `test_host_report.py` - Host report generation (Session 10) - 640 lines, 31 tests
- ✅ `test_site_report.py` - Site report generation (Session 10) - 541 lines, 25 tests

### Integration Tests (`tests/integration/`)
- **Purpose:** Test end-to-end workflows
- **Speed:** Slower (5-30 seconds each)
- **Dependencies:** Real PostgreSQL, mock SSH servers
- **Coverage Target:** 80% overall

**Integration Test Files (To Be Implemented):**
- ⏳ `test_monitoring_workflow.py` - Complete monitoring cycle
- ⏳ `test_api_endpoints.py` - REST API functionality
- ⏳ `test_database_integration.py` - Real database operations

## Running Tests Locally

⚠️ **IMPORTANT: Docker Requirement**

Since dthostmon runs entirely in a Docker container, **all pytest commands must be executed from inside the container**. The application dependencies (PostgreSQL client libraries, Python packages) are only available in the container environment.

### Option 1: Run Tests Inside Docker Container (Recommended)

```bash
# From the dthostmon directory on your host
docker compose build
docker compose up -d

# Run tests inside the container
docker compose exec dthostmon pytest

# Run with verbose output
docker compose exec dthostmon pytest -v

# Run with coverage report
docker compose exec dthostmon pytest --cov=src/dthostmon --cov-report=html

# Copy coverage report to host
docker compose cp dthostmon:/home/dthostmon/htmlcov ./htmlcov-docker
```

### Option 2: Interactive Testing in Container

```bash
# Open an interactive bash shell in the container
docker compose exec dthostmon /bin/bash

# Now you can run pytest commands directly
pytest tests/unit/
pytest tests/unit/test_config.py::test_config_loads_successfully
pytest --cov=src/dthostmon --cov-report=term-missing

# Exit the container
exit
```

## Python Virtual Environment Setup

### Option A: Using DivTools venv System (Recommended if DIVTOOLS is available)

If you have the divtools workspace synced, you can use the centralized venv system stored in `$DIVTOOLS/scripts/venvs/`. This keeps venvs centralized and easy to sync across hosts.

**Available Commands:**

```bash
# Create a venv for dthostmon
pvcr dthostmon
# Alias for: python_venv_create dthostmon

# List all available venvs
pvls
# Alias for: python_venv_ls

# Activate the dthostmon venv
pvact dthostmon
# Alias for: python_venv_activate dthostmon
```

**How the DivTools venv System Works:**

- **Location:** All venvs stored in `$DIVTOOLS/scripts/venvs/`
- **Functions defined in:** `$DIVTOOLS/dotfiles/.bash_profile`
- **Aliases defined in:** `$DIVTOOLS/dotfiles/.bash_aliases`
- **Purpose:** Centralize and manage Python virtual environments

**How `python_venv_create` works:**
```bash
function python_venv_create() {
    local venv_name="${1:-venv}"  # Takes venv name as argument
    local venv_path="$VENV_DIR/$venv_name"  # Uses VENV_DIR (default: $DIVTOOLS/scripts/venvs/)
    python3 -m venv "$venv_path"  # Creates using standard python venv module
}
```

**How `python_venv_ls` works:**
```bash
function python_venv_ls() {
    # Lists all directories in $VENV_DIR to show available venvs
    for dir in "$VENV_DIR"/*/; do
        echo "$(basename "$dir")"
    done
}
```

**How `python_venv_activate` works:**
```bash
function python_venv_activate() {
    local venv_name="${1:-venv}"
    local venv_path="$VENV_DIR/$venv_name"
    source "$venv_path/bin/activate"  # Activates the venv like normal
}
```

**Benefits of DivTools venv System:**
- ✅ Single location for all venvs (easy to find and manage)
- ✅ Easy to list: `pvls` shows all available venvs
- ✅ Quick activation: `pvact dthostmon` vs `source /path/to/venv/bin/activate`
- ✅ Syncs across hosts with DIVTOOLS folder
- ✅ No need for per-project venvs cluttering the codebase

### Option B: Using Standard Python venv (Manual)

If DivTools venv system is not available, you can create a local venv:

```bash
# Create local venv in project directory
python3 -m venv venv
source venv/bin/activate

# Install development dependencies
pip install -r requirements-dev.txt
```

### Option C: Using direnv (Optional Enhancement)

You can add `.envrc` to automatically activate the venv when entering the directory:

```bash
# Install direnv (if not already installed)
brew install direnv  # or apt-get install direnv

# Create .envrc in dthostmon directory
echo 'source $DIVTOOLS/scripts/venvs/dthostmon/bin/activate' > .envrc

# Allow direnv to execute the file
direnv allow

# Now the venv activates automatically when you cd into dthostmon/
cd /home/divix/divtools/projects/dthostmon/
# venv is now active
```

## Docker-Based Testing

### Why Docker for Testing?

The dthostmon application is containerized, and all test dependencies (Python packages, system libraries) are defined in the Docker image. Testing inside the container ensures:

1. ✅ Consistent environment (no "works on my machine" issues)
2. ✅ All dependencies available (no missing packages on host)
3. ✅ Database connectivity (PostgreSQL can be integrated)
4. ✅ No pollution of host system
5. ✅ Exact replica of production environment

### Quick Test Commands

**Run all tests:**
```bash
docker compose exec dthostmon pytest
```

**Run unit tests only:**
```bash
docker compose exec dthostmon pytest tests/unit/ -v
```

**Run with coverage:**
```bash
docker compose exec dthostmon pytest --cov=src/dthostmon --cov-report=term-missing
```

**Run single test file:**
```bash
docker compose exec dthostmon pytest tests/unit/test_config.py -v
```

**Run specific test:**
```bash
docker compose exec dthostmon pytest tests/unit/test_config.py::test_config_loads_successfully -v
```

### Creating Test Aliases (Optional)

Create `.dthostmon-aliases` in the project directory for convenient testing:

```bash
# File: .dthostmon-aliases
alias dttest='docker compose exec dthostmon pytest'
alias dttestv='docker compose exec dthostmon pytest -v'
alias dttestcov='docker compose exec dthostmon pytest --cov=src/dthostmon --cov-report=term-missing'
alias dttestunit='docker compose exec dthostmon pytest tests/unit/ -v'
alias dtshell='docker compose exec dthostmon /bin/bash'
```

**Usage:**
```bash
# Source the aliases first (add to your .bashrc or .bash_profile)
source /path/to/dthostmon/.dthostmon-aliases

# Now use convenient aliases
dttest              # Run all tests
dttestv             # Run with verbose output
dttestcov           # Run with coverage
dttestunit          # Run unit tests only
dtshell             # Open interactive shell in container
```

## Creating New Tests

### Unit Test Template

```python
"""
Unit tests for [module name]
Last Updated: [date]
"""

import pytest
from unittest.mock import Mock, patch
from dthostmon.[module_path] import [ClassName]


@pytest.fixture
def sample_data():
    """Fixture for test data"""
    return {
        'key': 'value'
    }


def test_function_success(sample_data):
    """Test successful execution"""
    # Arrange
    instance = ClassName(sample_data)
    
    # Act
    result = instance.method()
    
    # Assert
    assert result == expected_value
    assert instance.state == expected_state


@patch('dthostmon.module.external_dependency')
def test_function_with_mock(mock_dependency):
    """Test with mocked external dependency"""
    # Setup mock
    mock_dependency.return_value = Mock(data='mocked')
    
    # Execute
    result = function_under_test()
    
    # Verify
    assert result is not None
    mock_dependency.assert_called_once()


def test_function_error_handling():
    """Test error handling"""
    with pytest.raises(ExpectedException) as exc_info:
        function_that_should_fail()
    
    assert "expected error message" in str(exc_info.value)
```

### Integration Test Template

```python
"""
Integration tests for [feature name]
Last Updated: [date]
"""

import pytest
from dthostmon.models import DatabaseManager
from dthostmon.core import MonitoringOrchestrator


@pytest.fixture(scope='module')
def db_manager():
    """Real database for integration tests"""
    db_url = "postgresql://test_user:test_pass@localhost:5432/dthostmon_test"
    manager = DatabaseManager(db_url)
    manager.create_tables()
    
    yield manager
    
    manager.drop_tables()


def test_end_to_end_monitoring(db_manager, config):
    """Test complete monitoring workflow"""
    # Setup
    orchestrator = MonitoringOrchestrator(config, db_manager)
    
    # Execute
    orchestrator.run_monitoring_cycle()
    
    # Verify results in database
    with db_manager.get_session() as session:
        runs = session.query(MonitoringRun).all()
        assert len(runs) > 0
```

## Test Fixtures and Mocking

### Available Fixtures (in `tests/conftest.py`)

| Fixture | Scope | Description |
|---------|-------|-------------|
| `test_config_file` | session | Temporary YAML config file |
| `test_env_file` | session | Temporary .env file |
| `config` | function | Loaded Config object |
| `db_manager` | function | In-memory SQLite database |
| `sample_host_data` | function | Sample host dictionary |
| `sample_log_data` | function | Sample log entries |
| `mock_ssh_key` | function | Temporary SSH key file |

### Using Fixtures

```python
def test_with_config(config):
    """Test using config fixture"""
    assert config.get('global.log_level') == 'DEBUG'


def test_with_database(db_manager, sample_host_data):
    """Test using database and sample data"""
    with db_manager.get_session() as session:
        host = Host(**sample_host_data)
        session.add(host)
        session.commit()
```

### Mocking External Services

**Mock SSH Connections:**
```python
@patch('paramiko.SSHClient')
def test_ssh_connection(mock_ssh_class):
    mock_client = Mock()
    mock_ssh_class.return_value = mock_client
    
    ssh_client = SSHClient('host', 22, 'user', '/key')
    ssh_client.connect()
    
    mock_client.connect.assert_called_once()
```

**Mock AI API Calls:**
```python
@patch('requests.post')
def test_ai_analysis(mock_post):
    mock_response = Mock()
    mock_response.json.return_value = {'choices': [{'message': {'content': '{}'}}]}
    mock_post.return_value = mock_response
    
    analyzer = AIAnalyzer(config)
    result = analyzer.analyze_logs(host, logs)
```

**Mock Email Sending:**
```python
@patch('smtplib.SMTP')
def test_email_alert(mock_smtp_class):
    mock_server = Mock()
    mock_smtp_class.return_value = mock_server
    
    email = EmailAlert(smtp_config)
    email.send_alert(recipients, subject, body)
    
    mock_server.sendmail.assert_called_once()
```

## Coverage Requirements

### Phase 1 Targets

| Module | Target Coverage | Critical? |
|--------|----------------|-----------|
| `utils/config.py` | 90% | ✓ |
| `core/ssh_client.py` | 90% | ✓ |
| `models/database.py` | 90% | ✓ |
| `core/orchestrator.py` | 85% | ✓ |
| `api/server.py` | 85% | |
| `core/ai_analyzer.py` | 80% | |
| `core/email_alert.py` | 80% | |
| **Overall** | **80%** | ✓ |

### Checking Coverage

```bash
# Run tests with coverage
pytest --cov=src/dthostmon --cov-report=term-missing

# View detailed HTML report
pytest --cov=src/dthostmon --cov-report=html
open htmlcov/index.html  # or xdg-open on Linux

# Check specific module
pytest --cov=src/dthostmon/utils --cov-report=term-missing tests/unit/test_config.py
```

### Coverage Report Output
```
Name                                   Stmts   Miss  Cover   Missing
--------------------------------------------------------------------
src/dthostmon/utils/config.py           120      8    93%   45-47, 89-92
src/dthostmon/core/ssh_client.py        145     12    92%   67-69, 134-140
src/dthostmon/models/database.py         87      5    94%   102-105
--------------------------------------------------------------------
TOTAL                                   1234     89    93%
```

## CI/CD Pipeline

### GitHub Actions Workflow

The CI/CD pipeline runs automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main` or `develop`

**Pipeline Stages:**

1. **Test (Matrix)**
   - Python 3.9, 3.10, 3.11
   - Run unit tests
   - Generate coverage report
   - Upload to Codecov

2. **Lint**
   - flake8 (syntax errors)
   - pylint (code quality)
   - black (code formatting)

3. **Docker Build**
   - Build Docker image
   - Test image runs successfully

### Running CI/CD Locally

**Simulate GitHub Actions:**
```bash
# Install act (GitHub Actions local runner)
# https://github.com/nektos/act

# Run workflow locally
act push
```

**Manual CI/CD Steps:**
```bash
# 1. Run tests
pytest tests/unit/ --cov=src/dthostmon --cov-report=xml

# 2. Lint code
flake8 src/dthostmon --count --max-line-length=127 --statistics
pylint src/dthostmon

# 3. Check formatting
black --check src/dthostmon

# 4. Build Docker
docker build -t dthostmon:test .
docker run --rm dthostmon:test python3 -c "import dthostmon"
```

### CI/CD Configuration Files

- `.github/workflows/ci.yml` - GitHub Actions workflow
- `pytest.ini` - pytest configuration
- `.pylintrc` - pylint rules (create if customizing)
- `requirements-dev.txt` - Development dependencies

## Debugging Test Failures

### Common Issues

**1. Import Errors**
```bash
# Problem: Module not found
# Solution: Ensure src/ is in PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)/src"
pytest
```

**2. Database Connection Errors**
```python
# Problem: PostgreSQL not available
# Solution: Use SQLite for unit tests
db_manager = DatabaseManager("sqlite:///:memory:")
```

**3. SSH Key Errors**
```bash
# Problem: SSH key format invalid
# Solution: Use mock_ssh_key fixture or create valid test key
ssh-keygen -t ed25519 -f tests/fixtures/test_key -N ""
```

**4. Coverage Threshold Failures**
```bash
# Problem: Coverage below 80%
# Solution: Add tests for uncovered code
pytest --cov=src/dthostmon --cov-report=term-missing
# Check 'Missing' column for line numbers
```

### Debugging Techniques

**Run with verbose output:**
```bash
pytest -vv tests/unit/test_config.py
```

**Print stdout (for debugging):**
```bash
pytest -s tests/unit/test_config.py
```

**Drop into debugger on failure:**
```bash
pytest --pdb tests/unit/test_config.py
```

**Show local variables on failure:**
```bash
pytest -l tests/unit/test_config.py
```

**Run only failed tests:**
```bash
pytest --lf  # Last failed
pytest --ff  # Failed first, then others
```

## Best Practices

1. **Write tests first** (TDD) when adding new features
2. **Mock external dependencies** in unit tests
3. **Use fixtures** for reusable test data
4. **Test edge cases** and error conditions
5. **Keep tests fast** - unit tests under 1 second
6. **Use descriptive test names** - explain what is being tested
7. **One assertion per test** (when practical)
8. **Clean up after tests** - use fixtures with teardown
9. **Document complex tests** with comments
10. **Run full test suite before committing**

## Additional Resources

- [pytest Documentation](https://docs.pytest.org/)
- [pytest-cov Documentation](https://pytest-cov.readthedocs.io/)
- [unittest.mock Guide](https://docs.python.org/3/library/unittest.mock.html)
- [Testing Best Practices](https://testdriven.io/blog/testing-best-practices/)

## Questions?

Refer to:
- **PRD:** `docs/PRD.md` - Feature requirements
- **Project History:** `docs/PROJECT-HISTORY.md` - Design decisions
- **README:** `README.md` - General usage
