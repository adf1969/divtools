# Samba AD DC Test Suite
# Last Updated: 12/6/2025 10:00:00 PM CST
#
# pytest-based tests for verifying Samba AD DC functionality
# Tests cover: DNS, LDAP, Kerberos, SMB, Domain Info
#
# Usage:
#   pytest test_ads.py -v
#   pytest test_ads.py::test_domain_info -v

import subprocess
import socket
import pytest
import os

# Configuration
CONTAINER_NAME = "samba-ads"
DOMAIN = os.getenv("ADS_DOMAIN", "avctn.lan")
REALM = os.getenv("ADS_REALM", "AVCTN.LAN")
HOST_IP = os.getenv("ADS_HOST_IP", "10.1.1.98")


def run_container_command(cmd):
    """Execute command inside the Samba container."""
    full_cmd = ["docker", "exec", CONTAINER_NAME] + cmd
    try:
        result = subprocess.run(
            full_cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        pytest.fail(f"Command timed out: {' '.join(cmd)}")
    except Exception as e:
        pytest.fail(f"Failed to run command: {e}")


def run_host_command(cmd):
    """Execute command on the host."""
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30,
            shell=True
        )
        return result.returncode, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        pytest.fail(f"Command timed out: {cmd}")
    except Exception as e:
        pytest.fail(f"Failed to run command: {e}")


class TestContainerStatus:
    """Test container is running and responsive."""
    
    def test_container_running(self):
        """Verify samba-ads container is running."""
        returncode, stdout, stderr = run_host_command(
            f"docker ps --filter name={CONTAINER_NAME} --format '{{{{.Names}}}}'"
        )
        assert returncode == 0, f"Failed to check container status: {stderr}"
        assert CONTAINER_NAME in stdout, f"Container {CONTAINER_NAME} is not running"
    
    def test_container_healthy(self):
        """Verify container health check is passing."""
        returncode, stdout, stderr = run_host_command(
            f"docker inspect {CONTAINER_NAME} --format '{{{{.State.Health.Status}}}}'"
        )
        # Container may not have health status yet if just started
        if returncode == 0 and stdout.strip():
            # Only fail if explicitly unhealthy
            assert "unhealthy" not in stdout.lower(), f"Container is unhealthy: {stdout}"


class TestDomainInfo:
    """Test domain information and status."""
    
    def test_domain_info_command(self):
        """Verify samba-tool domain info works."""
        returncode, stdout, stderr = run_container_command(
            ["samba-tool", "domain", "info", "127.0.0.1"]
        )
        assert returncode == 0, f"domain info failed: {stderr}"
        assert "Forest" in stdout, "Missing Forest info in output"
        assert DOMAIN in stdout, f"Domain {DOMAIN} not found in output"
    
    def test_fsmo_roles(self):
        """Verify FSMO roles are assigned."""
        returncode, stdout, stderr = run_container_command(
            ["samba-tool", "fsmo", "show"]
        )
        assert returncode == 0, f"FSMO show failed: {stderr}"
        # Check for standard FSMO roles
        expected_roles = ["SchemaMasterRole", "DomainNamingMasterRole", "PDCEmulationMasterRole"]
        for role in expected_roles:
            assert role in stdout, f"Missing FSMO role: {role}"


class TestDNS:
    """Test DNS functionality."""
    
    def test_dns_srv_records(self):
        """Verify DNS SRV records for LDAP."""
        returncode, stdout, stderr = run_container_command(
            ["host", "-t", "SRV", f"_ldap._tcp.{DOMAIN}"]
        )
        assert returncode == 0, f"DNS SRV query failed: {stderr}"
        assert "has SRV record" in stdout, "No LDAP SRV records found"
    
    def test_dns_domain_resolution(self):
        """Verify domain name resolves."""
        returncode, stdout, stderr = run_container_command(
            ["host", DOMAIN]
        )
        assert returncode == 0, f"Domain resolution failed: {stderr}"
        assert "has address" in stdout or "has IPv6" in stdout, f"Domain {DOMAIN} did not resolve"
    
    def test_dns_reverse_lookup(self):
        """Verify reverse DNS lookup works."""
        returncode, stdout, stderr = run_container_command(
            ["host", HOST_IP]
        )
        # Reverse lookup may not be configured yet, so just check command works
        assert returncode == 0 or "not found" in stderr.lower(), f"Reverse lookup failed: {stderr}"


class TestLDAP:
    """Test LDAP functionality."""
    
    def test_ldap_anonymous_bind(self):
        """Verify LDAP anonymous queries work."""
        returncode, stdout, stderr = run_container_command(
            ["ldapsearch", "-H", "ldap://localhost", "-x", 
             "-b", f"DC={DOMAIN.split('.')[0]},DC={DOMAIN.split('.')[1]}", 
             "-s", "base"]
        )
        assert returncode == 0, f"LDAP anonymous bind failed: {stderr}"
        assert "dn:" in stdout, "No LDAP results returned"
    
    def test_ldap_rootdse(self):
        """Verify LDAP rootDSE is accessible."""
        returncode, stdout, stderr = run_container_command(
            ["ldapsearch", "-H", "ldap://localhost", "-x", 
             "-b", "", "-s", "base", "defaultNamingContext"]
        )
        assert returncode == 0, f"LDAP rootDSE query failed: {stderr}"
        assert "defaultNamingContext" in stdout, "Missing defaultNamingContext in rootDSE"


class TestSMB:
    """Test SMB/CIFS functionality."""
    
    def test_smb_shares_list(self):
        """Verify SMB shares are available (anonymous)."""
        returncode, stdout, stderr = run_container_command(
            ["smbclient", "-L", "localhost", "-N"]
        )
        # Anonymous listing may be restricted, check for either success or auth required
        assert returncode in [0, 1], f"SMB listing failed unexpectedly: {stderr}"
        # If successful, check for standard shares
        if returncode == 0:
            assert "SYSVOL" in stdout or "netlogon" in stdout, "Missing standard AD shares"
    
    def test_smbstatus(self):
        """Verify smbstatus command works."""
        returncode, stdout, stderr = run_container_command(
            ["smbstatus"]
        )
        assert returncode == 0, f"smbstatus failed: {stderr}"


class TestKerberos:
    """Test Kerberos functionality."""
    
    def test_kerberos_realm_config(self):
        """Verify krb5.conf is configured."""
        returncode, stdout, stderr = run_container_command(
            ["cat", "/etc/krb5.conf"]
        )
        assert returncode == 0, f"Failed to read krb5.conf: {stderr}"
        assert REALM in stdout, f"Realm {REALM} not found in krb5.conf"
        assert DOMAIN in stdout, f"Domain {DOMAIN} not found in krb5.conf"


class TestUsers:
    """Test user management functionality."""
    
    def test_list_users(self):
        """Verify samba-tool user list works."""
        returncode, stdout, stderr = run_container_command(
            ["samba-tool", "user", "list"]
        )
        assert returncode == 0, f"User list failed: {stderr}"
        assert "Administrator" in stdout, "Administrator user not found"
    
    def test_list_groups(self):
        """Verify samba-tool group list works."""
        returncode, stdout, stderr = run_container_command(
            ["samba-tool", "group", "list"]
        )
        assert returncode == 0, f"Group list failed: {stderr}"
        # Check for standard AD groups
        expected_groups = ["Domain Admins", "Domain Users", "Domain Computers"]
        for group in expected_groups:
            assert group in stdout, f"Missing standard group: {group}"


class TestReplication:
    """Test replication functionality."""
    
    def test_replication_status(self):
        """Verify replication status can be queried."""
        returncode, stdout, stderr = run_container_command(
            ["samba-tool", "drs", "showrepl"]
        )
        assert returncode == 0, f"Replication status query failed: {stderr}"
        # Single DC won't have partners, but command should work
        assert "DSA" in stdout or "no replication" in stdout.lower(), "Unexpected replication output"


class TestTime:
    """Test time synchronization."""
    
    def test_time_sync(self):
        """Verify container time is within 5 minutes of host time."""
        # Get host time
        _, host_time, _ = run_host_command("date +%s")
        host_timestamp = int(host_time.strip())
        
        # Get container time
        returncode, container_time, stderr = run_container_command(
            ["date", "+%s"]
        )
        assert returncode == 0, f"Failed to get container time: {stderr}"
        container_timestamp = int(container_time.strip())
        
        # Check difference (Kerberos requires < 5 minutes)
        time_diff = abs(host_timestamp - container_timestamp)
        assert time_diff < 300, f"Time difference too large: {time_diff} seconds (max 300)"


# Pytest configuration
def pytest_configure(config):
    """Configure pytest with custom markers."""
    config.addinivalue_line(
        "markers", "slow: marks tests as slow (deselect with '-m \"not slow\"')"
    )


if __name__ == "__main__":
    # Allow running directly with python
    pytest.main([__file__, "-v"])
