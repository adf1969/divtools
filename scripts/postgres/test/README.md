# PGAdmin Utility Script - Test Suite

## Overview

The `test_pga_util.sh` script provides comprehensive testing for `pga_util.sh` without modifying the production PGAdmin database.

## Safety Design

- **Read-only operations** (list, list-locked): Test against the real `/opt/pgadmin/pgadmin4.db`
- **Write operations** (unlock): Test against a temporary copy of the database in `/tmp/`
- **Automatic cleanup**: Test database copy is removed after tests complete
- **No production changes**: The real database is never modified during testing

## Running the Tests

### Prerequisites
- `sqlite3` command-line tool installed
- Read access to `/opt/pgadmin/pgadmin4.db` (may require sudo)
- Write access to `/tmp/` directory

### Basic Test Run

```bash
/home/divix/divtools/scripts/postgres/test/test_pga_util.sh
```

Or with logging:

```bash
sudo /home/divix/divtools/scripts/postgres/test/test_pga_util.sh
```

## Test Cases

### Read Operations (Real Database)
- **test_list_all_users**: Lists all PGAdmin users with status and metadata
- **test_list_locked_users**: Displays only locked user accounts
- **test_list_with_test_flag**: Verifies test mode doesn't affect output
- **test_help**: Validates help and usage information

### Write Operations (Test Database Copy)
- **test_unlock_user**: Tests unlocking a specific user
- **test_unlock_all_users**: Tests bulk unlock of all locked users
- Includes verification that test mode (`-t` flag) doesn't make changes

### Error Handling
- **test_invalid_args**: Validates error handling for invalid flags
- **test_no_action**: Verifies proper error when no action specified

## Test Output Example

```
[2026-02-13 12:00:00] [INFO] Starting pga_util.sh test suite...
[2026-02-13 12:00:00] [INFO] Real DB: /opt/pgadmin/pgadmin4.db
[2026-02-13 12:00:00] [INFO] Test DB: /tmp/pga_util_tests_12345/pgadmin4.db
[2026-02-13 12:00:00] [INFO] Setting up test environment...
[2026-02-13 12:00:00] [INFO] Creating test database copy...
[2026-02-13 12:00:00] [INFO] Test environment ready
...
[2026-02-13 12:00:15] [INFO] ===============================================
[2026-02-13 12:00:15] [INFO] Test Summary
[2026-02-13 12:00:15] [INFO] ===============================================
[2026-02-13 12:00:15] [INFO] Total Tests Run:  12
[2026-02-13 12:00:15] [INFO] Tests Passed:     12
[2026-02-13 12:00:15] [INFO] Tests Failed:     0
[2026-02-13 12:00:15] [INFO] Result: ✔ ALL TESTS PASSED
```

## Database Schema Validation

The test suite automatically validates against the actual PGAdmin SQLite schema:

- **id**: User ID (INTEGER)
- **username**: Unique username (VARCHAR)
- **email**: User email address (VARCHAR)
- **active**: Account active status (BOOLEAN)
- **locked**: Account locked status (BOOLEAN)
- **login_attempts**: Failed login attempt counter (INTEGER)
- **auth_source**: Authentication source (VARCHAR)

## Troubleshooting

### Permission Denied Error
```
[ERROR] No read permission for /opt/pgadmin/pgadmin4.db
[INFO] Try running with sudo: sudo test_pga_util.sh
```

**Solution**: Run the test with sudo:
```bash
sudo /home/divix/divtools/scripts/postgres/test/test_pga_util.sh
```

### Database File Not Found
```
[ERROR] PGAdmin database not found at /opt/pgadmin/pgadmin4.db
```

**Solution**: Verify PGAdmin is running and the database exists. Check if you're on the correct host.

### Test Failures
If tests fail, review the output for specific error messages. Common issues:
- sqlite3 not installed
- PGAdmin database corrupted
- Insufficient permissions to write to `/tmp/`

## Integration with CI/CD

To run tests in CI/CD pipelines:

```bash
#!/bin/bash
set -e

# Run tests with sudo
sudo /home/divix/divtools/scripts/postgres/test/test_pga_util.sh

# Check exit code
if [ $? -eq 0 ]; then
    echo "All tests passed"
else
    echo "Tests failed"
    exit 1
fi
```

## Files

- **pga_util.sh**: Main PGAdmin utility script
- **test/test_pga_util.sh**: Test suite
- **test/README.md**: This file
