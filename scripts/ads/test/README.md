# Samba AD DC Test Suite

**Last Updated:** December 6, 2025

## Overview

pytest-based test suite for comprehensive Samba Active Directory Domain Controller verification. Tests cover all critical AD services: DNS, LDAP, Kerberos, SMB, and domain functionality.

## Installation

### Using Virtual Environment (Recommended)

The `dt_ads_setup.sh` script automatically creates and manages a virtual environment. If you need to set it up manually:

```bash
# Create virtual environment
cd /home/divix/divtools/scripts/ads
python3 -m venv .venv

# Activate
source .venv/bin/activate

# Install dependencies
pip install -r test/requirements.txt
```

### Using divtools python_venv Functions

```bash
# Create venv
python_venv_create ads-tests -y

# Activate
python_venv_activate ads-tests

# Install requirements
pip install -r /home/divix/divtools/scripts/ads/test/requirements.txt
```

## Running Tests

### All Tests

```bash
# From scripts/ads/ directory with venv activated
pytest test/test_ads.py -v

# Or directly
cd /home/divix/divtools/scripts/ads
source .venv/bin/activate
pytest test/ -v
```

### Specific Test Classes

```bash
# Test only DNS functionality
pytest test/test_ads.py::TestDNS -v

# Test only domain info
pytest test/test_ads.py::TestDomainInfo -v

# Test only LDAP
pytest test/test_ads.py::TestLDAP -v
```

### Specific Test Functions

```bash
# Test specific function
pytest test/test_ads.py::TestDNS::test_dns_srv_records -v
```

### With Coverage

```bash
pytest test/ --cov=. --cov-report=html -v
```

## Test Categories

### Container Status
- `test_container_running`: Verify container is running
- `test_container_healthy`: Verify health check passing

### Domain Info
- `test_domain_info_command`: Verify domain info retrieval
- `test_fsmo_roles`: Verify FSMO roles assigned

### DNS
- `test_dns_srv_records`: Verify LDAP SRV records
- `test_dns_domain_resolution`: Verify domain resolves
- `test_dns_reverse_lookup`: Verify reverse DNS

### LDAP
- `test_ldap_anonymous_bind`: Verify anonymous LDAP queries
- `test_ldap_rootdse`: Verify rootDSE accessible

### SMB
- `test_smb_shares_list`: Verify SMB shares available
- `test_smbstatus`: Verify smbstatus works

### Kerberos
- `test_kerberos_realm_config`: Verify krb5.conf configured

### Users & Groups
- `test_list_users`: Verify user listing
- `test_list_groups`: Verify group listing

### Replication
- `test_replication_status`: Verify replication status query

### Time Sync
- `test_time_sync`: Verify time within 5 minutes of host

## Environment Variables

Tests use these environment variables (with defaults):

```bash
export ADS_DOMAIN="avctn.lan"
export ADS_REALM="AVCTN.LAN"
export ADS_HOST_IP="10.1.1.98"
```

These are automatically loaded from `sites/$SITE_NAME/$HOSTNAME/.env.$HOSTNAME` by `dt_ads_setup.sh`.

## Integration with dt_ads_setup.sh

The test suite is automatically invoked when you select "ADS Status Check" from the dt_ads_setup.sh menu. The script:

1. Creates a virtual environment if needed
2. Installs dependencies
3. Runs all tests with verbose output
4. Deactivates the venv after completion

## Continuous Testing

For continuous monitoring, create a cron job:

```bash
# Edit crontab
crontab -e

# Add daily test at 6 AM
0 6 * * * /home/divix/divtools/scripts/ads/.venv/bin/pytest /home/divix/divtools/scripts/ads/test/ -v > /var/log/ads-tests.log 2>&1
```

## Troubleshooting

### Container Not Running

```
ERROR: Container 'samba-ads' is not running
```

**Solution:** Start the container first with `dt_ads_setup.sh` or:
```bash
cd /home/divix/divtools/docker/sites/s01-7692nw/ads1-98
docker compose -f dc-ads1-98.yml up -d
```

### LDAP Connection Refused

```
ldapsearch: Can't contact LDAP server
```

**Solution:** Wait for container to finish provisioning (2-5 minutes) or check container logs:
```bash
docker logs samba-ads
```

### Time Sync Failed

```
AssertionError: Time difference too large: 350 seconds (max 300)
```

**Solution:** Fix NTP synchronization on host:
```bash
sudo systemctl restart systemd-timesyncd
# or
sudo systemctl restart chrony
```

### Import Errors

```
ModuleNotFoundError: No module named 'pytest'
```

**Solution:** Activate venv and install requirements:
```bash
source /home/divix/divtools/scripts/ads/.venv/bin/activate
pip install -r test/requirements.txt
```

## Adding New Tests

To add custom tests:

1. Create a new test class in `test_ads.py`
2. Follow the naming convention: `TestCategoryName`
3. Add test methods with `test_` prefix
4. Use `run_container_command()` or `run_host_command()` helpers

Example:

```python
class TestCustomCheck:
    """Test custom functionality."""
    
    def test_custom_feature(self):
        """Verify custom feature works."""
        returncode, stdout, stderr = run_container_command(
            ["your-command", "args"]
        )
        assert returncode == 0, f"Command failed: {stderr}"
        assert "expected" in stdout, "Missing expected output"
```

## References

- **pytest Documentation:** https://docs.pytest.org/
- **Samba Wiki:** https://wiki.samba.org/
- **dt_ads_setup.sh:** `/home/divix/divtools/scripts/ads/dt_ads_setup.sh`
- **Implementation Steps:** `/home/divix/divtools/projects/ads/phase1-configs/IMPLEMENTATION-STEPS.md`
