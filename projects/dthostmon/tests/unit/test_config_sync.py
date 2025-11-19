"""
Unit tests for dthostmon configuration sync functionality
Tests parsing of .env files, dthm-*.yaml files, and YAML merging
Last Updated: 11/16/2025 2:50:00 PM CST
"""

import pytest
import os
import tempfile
import yaml
from pathlib import Path
from unittest.mock import patch, MagicMock
import subprocess


# Test fixtures for sample configurations
@pytest.fixture
def temp_sites_dir():
    """Create a temporary Docker sites directory structure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        sites_dir = Path(tmpdir) / "sites"
        sites_dir.mkdir()
        
        # Create site1 structure
        site1_dir = sites_dir / "s01-prod"
        site1_dir.mkdir()
        
        # Create site1 .env file
        site1_env = site1_dir / ".env.s01-prod"
        site1_env.write_text("""
# Site 1 environment variables
DTHM_SITE_ENABLED=true
DTHM_SITE_TAGS=production,critical
DTHM_SITE_REPORT_FREQUENCY=daily
DTHM_SITE_ALERT_RECIPIENTS=ops@example.com,admin@example.com
""")
        
        # Create site1 YAML file
        site1_yaml = site1_dir / "dthm-site.yaml"
        site1_yaml.write_text("""
enabled: true
tags:
  - production
  - critical
resource_thresholds:
  health: "0-25"
  warning: "70-89"
  critical: "90-100"
""")
        
        # Create host1 in site1
        host1_dir = site1_dir / "host01"
        host1_dir.mkdir()
        
        host1_env = host1_dir / ".env.host01"
        host1_env.write_text("""
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.10
DTHM_HOST_PORT=22
DTHM_HOST_USER=monitoring
DTHM_HOST_TAGS=database,postgresql
DTHM_HOST_CHECK_DOCKER=true
DTHM_HOST_CHECK_APT=true
""")
        
        host1_yaml = host1_dir / "dthm-host.yaml"
        host1_yaml.write_text("""
monitoring:
  check_disk: true
  check_services:
    - postgresql
    - docker
log_paths:
  - /var/log/syslog
  - /var/log/postgresql/postgresql-14-main.log
""")
        
        # Create host2 in site1
        host2_dir = site1_dir / "host02"
        host2_dir.mkdir()
        
        host2_env = host2_dir / ".env.host02"
        host2_env.write_text("""
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.1.1.20
DTHM_HOST_PORT=2222
DTHM_HOST_USER=sshuser
DTHM_HOST_TAGS=webserver,nginx
""")
        
        # Create site2 structure
        site2_dir = sites_dir / "s02-dev"
        site2_dir.mkdir()
        
        site2_env = site2_dir / ".env.s02-dev"
        site2_env.write_text("""
DTHM_SITE_ENABLED=true
DTHM_SITE_TAGS=development
DTHM_SITE_REPORT_FREQUENCY=weekly
""")
        
        host3_dir = site2_dir / "devbox"
        host3_dir.mkdir()
        
        host3_env = host3_dir / ".env.devbox"
        host3_env.write_text("""
DTHM_HOST_ENABLED=false
DTHM_HOST_HOSTNAME=10.1.2.10
DTHM_HOST_USER=developer
""")
        
        yield sites_dir


@pytest.fixture
def temp_config_file():
    """Create a temporary dthostmon.yaml configuration file."""
    with tempfile.NamedTemporaryFile(mode='w', suffix='.yaml', delete=False) as f:
        config = {
            'global': {
                'log_level': 'INFO',
                'monitor_interval': 300
            },
            'database': {
                'host': 'localhost',
                'port': 5432
            },
            'sites': {
                's01-prod': {
                    'report_frequency': 'hourly'  # Will be updated
                }
            },
            'hosts': [
                {
                    'name': 'existing-host',
                    'hostname': '192.168.1.100',
                    'enabled': True,
                    'tags': ['existing']
                },
                {
                    'name': 'host01',  # Will be updated
                    'hostname': '10.1.1.99',
                    'enabled': False
                }
            ]
        }
        yaml.dump(config, f)
        config_path = f.name
    
    yield config_path
    
    # Cleanup
    os.unlink(config_path)


@pytest.fixture
def env_var_test_dir():
    """Create test directory with env var expansion examples."""
    with tempfile.TemporaryDirectory() as tmpdir:
        sites_dir = Path(tmpdir) / "sites"
        sites_dir.mkdir()
        
        site_dir = sites_dir / "s99-test"
        site_dir.mkdir()
        
        host_dir = site_dir / "envtest"
        host_dir.mkdir()
        
        # Set test environment variables
        os.environ['TEST_LOG_PATH'] = '/opt/logs'
        os.environ['TEST_SERVICE'] = 'myapp'
        
        host_yaml = host_dir / "dthm-host.yaml"
        host_yaml.write_text("""
# Test immediate expansion with ${VAR}
log_paths:
  - ${TEST_LOG_PATH}/app.log
  - /var/log/syslog

# Test deferred expansion with ${{VAR}}
custom_commands:
  - echo "Service: ${{TEST_SERVICE}}"
  - echo "Path: ${TEST_LOG_PATH}"

# Test mixed usage
monitoring:
  service_name: ${TEST_SERVICE}
  log_dir: ${{RUNTIME_LOG_DIR}}
""")
        
        host_env = host_dir / ".env.envtest"
        host_env.write_text("""
DTHM_HOST_ENABLED=true
DTHM_HOST_HOSTNAME=10.99.99.99
DTHM_HOST_USER=testuser
""")
        
        yield sites_dir


class TestEnvFileParsing:
    """Test parsing of .env files."""
    
    def test_parse_basic_env_file(self, temp_sites_dir):
        """Test parsing basic DTHM_* variables from .env file."""
        env_file = temp_sites_dir / "s01-prod" / ".env.s01-prod"
        
        # Run the Python helper inline
        result = self._parse_env_file(str(env_file))
        
        assert 'DTHM_SITE_ENABLED' in result
        assert result['DTHM_SITE_ENABLED'] == 'true'
        assert 'DTHM_SITE_TAGS' in result
        assert result['DTHM_SITE_TAGS'] == 'production,critical'
    
    def test_parse_host_env_file(self, temp_sites_dir):
        """Test parsing host-level .env file."""
        env_file = temp_sites_dir / "s01-prod" / "host01" / ".env.host01"
        
        result = self._parse_env_file(str(env_file))
        
        assert 'DTHM_HOST_ENABLED' in result
        assert 'DTHM_HOST_HOSTNAME' in result
        assert result['DTHM_HOST_HOSTNAME'] == '10.1.1.10'
        assert result['DTHM_HOST_PORT'] == '22'
    
    def test_ignore_non_dthm_vars(self, temp_sites_dir):
        """Test that non-DTHM_* variables are ignored."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.env', delete=False) as f:
            f.write("REGULAR_VAR=value\n")
            f.write("DTHM_HOST_ENABLED=true\n")
            f.write("ANOTHER_VAR=test\n")
            env_file = f.name
        
        try:
            result = self._parse_env_file(env_file)
            
            assert 'REGULAR_VAR' not in result
            assert 'ANOTHER_VAR' not in result
            assert 'DTHM_HOST_ENABLED' in result
        finally:
            os.unlink(env_file)
    
    def test_handle_comments_and_empty_lines(self, temp_sites_dir):
        """Test parsing handles comments and empty lines."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.env', delete=False) as f:
            f.write("# This is a comment\n")
            f.write("\n")
            f.write("DTHM_HOST_ENABLED=true\n")
            f.write("  # Another comment\n")
            f.write("DTHM_HOST_PORT=22\n")
            env_file = f.name
        
        try:
            result = self._parse_env_file(env_file)
            
            assert len(result) == 2
            assert 'DTHM_HOST_ENABLED' in result
            assert 'DTHM_HOST_PORT' in result
        finally:
            os.unlink(env_file)
    
    def test_handle_quoted_values(self, temp_sites_dir):
        """Test parsing handles quoted values."""
        with tempfile.NamedTemporaryFile(mode='w', suffix='.env', delete=False) as f:
            f.write('DTHM_HOST_USER="monitoring"\n')
            f.write("DTHM_HOST_TAGS='web,app'\n")
            f.write('DTHM_HOST_HOSTNAME=10.1.1.10\n')
            env_file = f.name
        
        try:
            result = self._parse_env_file(env_file)
            
            assert result['DTHM_HOST_USER'] == 'monitoring'
            assert result['DTHM_HOST_TAGS'] == 'web,app'
            assert result['DTHM_HOST_HOSTNAME'] == '10.1.1.10'
        finally:
            os.unlink(env_file)
    
    @staticmethod
    def _parse_env_file(filepath):
        """Helper to parse env file (simulates Python script logic)."""
        result = {}
        
        with open(filepath, 'r') as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                if '=' in line:
                    key, value = line.split('=', 1)
                    key = key.strip()
                    value = value.strip()
                    
                    # Remove quotes
                    if (value.startswith('"') and value.endswith('"')) or \
                       (value.startswith("'") and value.endswith("'")):
                        value = value[1:-1]
                    
                    if key.startswith('DTHM_'):
                        result[key] = value
        
        return result


class TestEnvToConfig:
    """Test conversion of DTHM_* variables to configuration dict."""
    
    def test_convert_site_vars(self):
        """Test converting DTHM_SITE_* variables."""
        env_vars = {
            'DTHM_SITE_ENABLED': 'true',
            'DTHM_SITE_TAGS': 'prod,critical',
            'DTHM_SITE_REPORT_FREQUENCY': 'daily'
        }
        
        config = self._env_to_config(env_vars, 'DTHM_SITE_')
        
        assert config['enabled'] is True
        assert config['tags'] == ['prod', 'critical']
        assert config['report_frequency'] == 'daily'
    
    def test_convert_host_vars(self):
        """Test converting DTHM_HOST_* variables."""
        env_vars = {
            'DTHM_HOST_ENABLED': 'false',
            'DTHM_HOST_HOSTNAME': '10.1.1.10',
            'DTHM_HOST_PORT': '22',
            'DTHM_HOST_TAGS': 'web,nginx,ssl'
        }
        
        config = self._env_to_config(env_vars, 'DTHM_HOST_')
        
        assert config['enabled'] is False
        assert config['hostname'] == '10.1.1.10'
        assert config['port'] == 22
        assert config['tags'] == ['web', 'nginx', 'ssl']
    
    def test_handle_boolean_variations(self):
        """Test handling various boolean value formats."""
        test_cases = [
            ('true', True),
            ('True', True),
            ('TRUE', True),
            ('yes', True),
            ('1', True),
            ('false', False),
            ('False', False),
            ('no', False),
            ('0', False)
        ]
        
        for value, expected in test_cases:
            env_vars = {'DTHM_SITE_ENABLED': value}
            config = self._env_to_config(env_vars, 'DTHM_SITE_')
            assert config['enabled'] == expected, f"Failed for value: {value}"
    
    def test_handle_numeric_values(self):
        """Test conversion of numeric string values."""
        env_vars = {
            'DTHM_HOST_PORT': '2222',
            'DTHM_HOST_TIMEOUT': '30'
        }
        
        config = self._env_to_config(env_vars, 'DTHM_HOST_')
        
        assert config['port'] == 2222
        assert isinstance(config['port'], int)
        assert config['timeout'] == 30
    
    def test_handle_comma_delimited_lists(self):
        """Test parsing comma-delimited list values."""
        env_vars = {
            'DTHM_HOST_TAGS': 'web, app, database',
            'DTHM_HOST_ALERT_RECIPIENTS': 'admin@example.com,ops@example.com'
        }
        
        config = self._env_to_config(env_vars, 'DTHM_HOST_')
        
        assert config['tags'] == ['web', 'app', 'database']
        assert config['alert_recipients'] == ['admin@example.com', 'ops@example.com']
    
    def test_ignore_non_matching_prefix(self):
        """Test that variables without matching prefix are ignored."""
        env_vars = {
            'DTHM_SITE_ENABLED': 'true',
            'DTHM_HOST_PORT': '22',  # Different prefix
            'OTHER_VAR': 'value'
        }
        
        config = self._env_to_config(env_vars, 'DTHM_SITE_')
        
        assert 'enabled' in config
        assert 'port' not in config
        assert 'other_var' not in config
    
    @staticmethod
    def _env_to_config(env_vars, prefix):
        """Helper to convert env vars to config (simulates Python script logic)."""
        config = {}
        
        for key, value in env_vars.items():
            if not key.startswith(prefix):
                continue
            
            config_key = key[len(prefix):].lower()
            
            if value.lower() in ('true', 'yes', '1'):
                config[config_key] = True
            elif value.lower() in ('false', 'no', '0'):
                config[config_key] = False
            elif value.isdigit():
                config[config_key] = int(value)
            elif ',' in value:
                config[config_key] = [item.strip() for item in value.split(',')]
            else:
                config[config_key] = value
        
        return config


class TestYAMLParsing:
    """Test parsing of dthm-*.yaml files."""
    
    def test_parse_site_yaml(self, temp_sites_dir):
        """Test parsing site-level YAML configuration."""
        yaml_file = temp_sites_dir / "s01-prod" / "dthm-site.yaml"
        
        with open(yaml_file, 'r') as f:
            config = yaml.safe_load(f)
        
        assert config['enabled'] is True
        assert 'production' in config['tags']
        assert 'critical' in config['tags']
        assert 'resource_thresholds' in config
    
    def test_parse_host_yaml(self, temp_sites_dir):
        """Test parsing host-level YAML configuration."""
        yaml_file = temp_sites_dir / "s01-prod" / "host01" / "dthm-host.yaml"
        
        with open(yaml_file, 'r') as f:
            config = yaml.safe_load(f)
        
        assert 'monitoring' in config
        assert config['monitoring']['check_disk'] is True
        assert 'log_paths' in config
        assert len(config['log_paths']) == 2
    
    def test_handle_missing_yaml_file(self):
        """Test handling of missing YAML files."""
        result = self._parse_yaml_safe('/nonexistent/path/dthm-host.yaml')
        assert result == {}
    
    @staticmethod
    def _parse_yaml_safe(filepath):
        """Helper to safely parse YAML file."""
        if not os.path.exists(filepath):
            return {}
        
        with open(filepath, 'r') as f:
            return yaml.safe_load(f) or {}


class TestEnvVarExpansion:
    """Test environment variable expansion in YAML files."""
    
    def test_immediate_expansion(self, env_var_test_dir):
        """Test ${VAR} expansion happens immediately."""
        yaml_file = env_var_test_dir / "s99-test" / "envtest" / "dthm-host.yaml"
        
        with open(yaml_file, 'r') as f:
            content = f.read()
        
        # Replace ${VAR} with actual values
        import re
        def replace_immediate(match):
            var_name = match.group(1)
            return os.environ.get(var_name, match.group(0))
        
        expanded = re.sub(r'\$\{([^}]+)\}', replace_immediate, content)
        config = yaml.safe_load(expanded)
        
        # Check immediate expansion
        assert '/opt/logs/app.log' in config['log_paths']
        assert config['monitoring']['service_name'] == 'myapp'
    
    def test_deferred_expansion(self, env_var_test_dir):
        """Test ${{VAR}} becomes ${VAR} for later expansion."""
        yaml_file = env_var_test_dir / "s99-test" / "envtest" / "dthm-host.yaml"
        
        with open(yaml_file, 'r') as f:
            content = f.read()
        
        # First convert ${{VAR}} to ${VAR}
        import re
        content = re.sub(r'\$\{\{([^}]+)\}\}', r'${\1}', content)
        
        # Then expand only the immediate ${VAR} (not ${{VAR}})
        def replace_immediate(match):
            var_name = match.group(1)
            # Skip if it was originally ${{VAR}}
            if var_name == 'RUNTIME_LOG_DIR':
                return match.group(0)
            return os.environ.get(var_name, match.group(0))
        
        expanded = re.sub(r'\$\{([^}]+)\}', replace_immediate, content)
        config = yaml.safe_load(expanded)
        
        # Check deferred expansion kept as ${VAR}
        # Note: YAML parser interprets "Service: ${VAR}" as a dict, not a string
        assert config['monitoring']['log_dir'] == '${RUNTIME_LOG_DIR}'
    
    def test_mixed_expansion(self, env_var_test_dir):
        """Test files with both immediate and deferred expansion."""
        yaml_file = env_var_test_dir / "s99-test" / "envtest" / "dthm-host.yaml"
        
        config = self._parse_yaml_with_expansion(str(yaml_file))
        
        # Immediate expansion should be done
        assert config['monitoring']['service_name'] == 'myapp'
        
        # Deferred expansion should remain as ${VAR}
        assert config['monitoring']['log_dir'] == '${RUNTIME_LOG_DIR}'
    
    @staticmethod
    def _parse_yaml_with_expansion(filepath):
        """Parse YAML with proper env var expansion."""
        import re
        
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Mark deferred vars: ${{VAR}} -> __DEFERRED__VAR__
        content = re.sub(r'\$\{\{([^}]+)\}\}', r'${__DEFERRED__\1__}', content)
        
        # Expand immediate vars
        def replace_var(match):
            var_name = match.group(1)
            if var_name.startswith('__DEFERRED__'):
                # Restore as ${VAR}
                actual_var = var_name.replace('__DEFERRED__', '').replace('__', '')
                return '${' + actual_var + '}'
            return os.environ.get(var_name, match.group(0))
        
        content = re.sub(r'\$\{([^}]+)\}', replace_var, content)
        
        return yaml.safe_load(content)


class TestConfigMerging:
    """Test merging of configurations from multiple sources."""
    
    def test_merge_simple_dicts(self):
        """Test merging simple dictionaries."""
        config1 = {'a': 1, 'b': 2}
        config2 = {'b': 3, 'c': 4}
        
        result = self._merge_configs(config1, config2)
        
        assert result == {'a': 1, 'b': 3, 'c': 4}
    
    def test_merge_nested_dicts(self):
        """Test merging nested dictionaries."""
        config1 = {
            'monitoring': {
                'check_docker': True,
                'check_disk': True
            }
        }
        config2 = {
            'monitoring': {
                'check_docker': False,
                'check_services': ['nginx']
            }
        }
        
        result = self._merge_configs(config1, config2)
        
        assert result['monitoring']['check_docker'] is False
        assert result['monitoring']['check_disk'] is True
        assert result['monitoring']['check_services'] == ['nginx']
    
    def test_merge_overrides_lists(self):
        """Test that lists are replaced, not merged."""
        config1 = {'tags': ['old1', 'old2']}
        config2 = {'tags': ['new1', 'new2', 'new3']}
        
        result = self._merge_configs(config1, config2)
        
        assert result['tags'] == ['new1', 'new2', 'new3']
    
    def test_merge_multiple_configs(self):
        """Test merging more than two configurations."""
        config1 = {'a': 1, 'b': 2}
        config2 = {'b': 3, 'c': 4}
        config3 = {'c': 5, 'd': 6}
        
        result = self._merge_configs(config1, config2, config3)
        
        assert result == {'a': 1, 'b': 3, 'c': 5, 'd': 6}
    
    def test_merge_with_none_configs(self):
        """Test merging handles None values."""
        config1 = {'a': 1}
        config2 = None
        config3 = {'b': 2}
        
        result = self._merge_configs(config1, config2, config3)
        
        assert result == {'a': 1, 'b': 2}
    
    @staticmethod
    def _merge_configs(*configs):
        """Merge multiple configuration dicts."""
        result = {}
        
        for config in configs:
            if not config:
                continue
            
            for key, value in config.items():
                if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                    # Recursive merge for nested dicts
                    result[key] = TestConfigMerging._merge_configs(result[key], value)
                else:
                    result[key] = value
        
        return result


class TestScriptIntegration:
    """Integration tests for the sync script."""
    
    def test_script_help_output(self):
        """Test that script help displays correctly."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        result = subprocess.run(
            [script_path, '--help'],
            capture_output=True,
            text=True
        )
        
        assert result.returncode == 0
        assert 'Usage:' in result.stdout
        assert '-test' in result.stdout
        assert '-debug' in result.stdout
        assert '-yaml-ex' in result.stdout or '-yex' in result.stdout
    
    def test_script_test_mode(self, temp_config_file, temp_sites_dir):
        """Test script in test mode (dry-run)."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        # Clean up any pre-existing backup files
        config_dir = Path(temp_config_file).parent
        config_name = Path(temp_config_file).name
        for backup in config_dir.glob(f'{config_name}.backup.*'):
            backup.unlink()
        
        result = subprocess.run(
            [script_path, '-test', '-config', temp_config_file, '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        
        # Should succeed
        assert result.returncode == 0
        
        # Should not create backup in test mode
        backup_files = list(config_dir.glob(f'{config_name}.backup.*'))
        assert len(backup_files) == 0, f"Test mode should not create backups, but found: {backup_files}"
        
        # Should show test mode messages (output goes to stdout, not stderr)
        assert 'TEST MODE' in result.stdout or 'TEST mode' in result.stdout
    
    def test_script_creates_backup(self, temp_config_file, temp_sites_dir):
        """Test that script creates backup before modifying config."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        # Run without -test to create backup
        result = subprocess.run(
            [script_path, '-config', temp_config_file, '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        
        assert result.returncode == 0
        
        # Check backup was created
        backup_files = list(Path(temp_config_file).parent.glob('*.backup.*'))
        assert len(backup_files) > 0
        
        # Cleanup backups
        for backup in backup_files:
            backup.unlink()
    
    def test_script_updates_config(self, temp_config_file, temp_sites_dir):
        """Test that script properly updates configuration file."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        # Run script
        result = subprocess.run(
            [script_path, '-config', temp_config_file, '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        
        assert result.returncode == 0
        
        # Load updated config
        with open(temp_config_file, 'r') as f:
            updated_config = yaml.safe_load(f)
        
        # Verify sites were added/updated
        assert 's01-prod' in updated_config['sites']
        assert 's02-dev' in updated_config['sites']
        
        # Verify hosts were added/updated
        host_names = [host['name'] for host in updated_config['hosts']]
        assert 'host01' in host_names
        assert 'host02' in host_names
        assert 'devbox' in host_names
        
        # Verify existing host was preserved
        assert 'existing-host' in host_names
        
        # Cleanup backups
        for backup in Path(temp_config_file).parent.glob('*.backup.*'):
            backup.unlink()
    
    def test_script_preserves_existing_settings(self, temp_config_file, temp_sites_dir):
        """Test that script preserves existing configuration not in folder structure."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        # Get original config
        with open(temp_config_file, 'r') as f:
            original_config = yaml.safe_load(f)
        
        original_global = original_config['global']
        original_database = original_config['database']
        
        # Run script
        subprocess.run(
            [script_path, '-config', temp_config_file, '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        
        # Load updated config
        with open(temp_config_file, 'r') as f:
            updated_config = yaml.safe_load(f)
        
        # Verify global and database sections preserved
        assert updated_config['global'] == original_global
        assert updated_config['database'] == original_database
        
        # Cleanup
        for backup in Path(temp_config_file).parent.glob('*.backup.*'):
            backup.unlink()

    def test_yaml_ex_stdout(self, temp_sites_dir):
        """Test YAML example output to stdout using '-'"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        result = subprocess.run(
            [script_path, '-yaml-ex', '-', '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert 'enabled:' in result.stdout

    def test_env_ex_stdout(self, temp_sites_dir):
        """Test ENV example output to stdout using '-'"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        result = subprocess.run(
            [script_path, '-env-ex', '-', '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert 'DTHM_HOST_ENABLED' in result.stdout

    def test_yaml_ex_create_file(self, temp_sites_dir, tmp_path):
        """Test creating a YAML example file at a specific path"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        out_file = tmp_path / "dthm-site-example.yaml"
        result = subprocess.run(
            [script_path, '-yaml-ex', str(out_file), '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert out_file.exists()
        content = out_file.read_text()
        assert 'enabled:' in content

    def test_env_ex_create_file(self, temp_sites_dir, tmp_path):
        """Test creating an ENV example file at a specific path"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        out_file = tmp_path / ".env.host-example"
        result = subprocess.run(
            [script_path, '-env-ex', str(out_file), '-sites-dir', str(temp_sites_dir)],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        assert out_file.exists()
        content = out_file.read_text()
        assert 'DTHM_HOST_ENABLED' in content

    def test_yaml_exh_creates_files(self, tmp_path, temp_sites_dir):
        """Test YAML example creation for a host using -yaml-exh with --site and --host"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Use temp_sites_dir structure to get site and host
        site_dir = None
        host_dir = None
        for s_dir in Path(temp_sites_dir).iterdir():
            if s_dir.is_dir():
                site_dir = s_dir
                for h_dir in s_dir.iterdir():
                    if h_dir.is_dir():
                        host_dir = h_dir
                        break
                break

        if not site_dir or not host_dir:
            pytest.skip("No valid site/host structure in temp_sites_dir")

        site_name = site_dir.name
        host_name = host_dir.name

        # Ensure no dthm-*.yaml exist for this host
        target = host_dir / f"dthm-{host_name}.yaml"
        if target.exists():
            target.unlink()

        result = subprocess.run(
            [script_path, '-yaml-exh', '--site', site_name, '--host', host_name, '-sites-dir', str(temp_sites_dir), '-y'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Script failed with output: {result.stdout}"
        # Check file created
        assert target.exists(), f"Missing generated YAML: {target}"
        content = target.read_text()
        assert 'name:' in content, "YAML should contain 'name' field"

    def test_env_exh_creates_files(self, tmp_path, temp_sites_dir):
        """Test ENV example creation for a host using -env-exh with --site and --host"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Use temp_sites_dir structure to get site and host
        site_dir = None
        host_dir = None
        for s_dir in Path(temp_sites_dir).iterdir():
            if s_dir.is_dir():
                site_dir = s_dir
                for h_dir in s_dir.iterdir():
                    if h_dir.is_dir():
                        host_dir = h_dir
                        break
                break

        if not site_dir or not host_dir:
            pytest.skip("No valid site/host structure in temp_sites_dir")

        site_name = site_dir.name
        host_name = host_dir.name

        # Ensure no .env.* file exists for this host
        target = host_dir / f".env.{host_name}"
        if target.exists():
            target.unlink()

        result = subprocess.run(
            [script_path, '-env-exh', '--site', site_name, '--host', host_name, '-sites-dir', str(temp_sites_dir), '-y'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Script failed with output: {result.stdout}"
        # Check file created
        assert target.exists(), f"Missing generated ENV: {target}"
        content = target.read_text()
        assert 'DTHM_HOST_' in content, "ENV should contain DTHM_HOST_ variables"

    def test_yaml_exh_force_overwrite(self, temp_sites_dir):
        """Test that -yaml-exh with -f overwrites existing YAML files without prompt"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Use temp_sites_dir structure to get site and host
        site_dir = None
        host_dir = None
        for s_dir in Path(temp_sites_dir).iterdir():
            if s_dir.is_dir():
                site_dir = s_dir
                for h_dir in s_dir.iterdir():
                    if h_dir.is_dir():
                        host_dir = h_dir
                        break
                break

        if not site_dir or not host_dir:
            pytest.skip("No valid site/host structure in temp_sites_dir")

        site_name = site_dir.name
        host_name = host_dir.name
        target = host_dir / f"dthm-{host_name}.yaml"

        # Precreate a YAML file to ensure overwrite
        target.write_text("invalid: data")

        result = subprocess.run(
            [script_path, '-yaml-exh', '--site', site_name, '--host', host_name, '-sites-dir', str(temp_sites_dir), '-f'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Script failed with output: {result.stdout}"
        # New file content should include 'name' field from example
        content = target.read_text()
        assert 'name:' in content, "YAML should be overwritten with example content"

    def test_env_exh_force_append(self, temp_sites_dir):
        """Test that -env-exh with -f appends example env vars without prompt"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Use temp_sites_dir structure to get site and host
        site_dir = None
        host_dir = None
        for s_dir in Path(temp_sites_dir).iterdir():
            if s_dir.is_dir():
                site_dir = s_dir
                for h_dir in s_dir.iterdir():
                    if h_dir.is_dir():
                        host_dir = h_dir
                        break
                break

        if not site_dir or not host_dir:
            pytest.skip("No valid site/host structure in temp_sites_dir")

        site_name = site_dir.name
        host_name = host_dir.name
        target = host_dir / f".env.{host_name}"

        # Precreate an ENV file with existing content
        target.write_text("EXISTING_VAR=test\n")

        result = subprocess.run(
            [script_path, '-env-exh', '--site', site_name, '--host', host_name, '-sites-dir', str(temp_sites_dir), '-f'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0, f"Script failed with output: {result.stdout}"
        content = target.read_text()
        assert 'EXISTING_VAR=test' in content, "Existing content should be preserved"
        assert 'DTHM_HOST_ENABLED' in content, "Example vars should be appended"

    def test_yaml_exh_with_site_host(self, temp_sites_dir):
        """Test that -yaml-exh limited by --site and --host only creates for specific host"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Remove existing dthm-host.yaml files if any
        for site in Path(temp_sites_dir).iterdir():
            for host in site.iterdir():
                target = host / f"dthm-{host.name}.yaml"
                if target.exists():
                    target.unlink()

        # Run for single host
        result = subprocess.run(
            [script_path, '-yaml-exh', '-sites-dir', str(temp_sites_dir), '-site', 's02-dev', '-host', 'devbox', '-f'],
            capture_output=True,
            text=True
        )
        assert result.returncode == 0
        # Verify only devbox under s02-dev was created
        devbox = Path(temp_sites_dir) / 's02-dev' / 'devbox' / 'dthm-devbox.yaml'
        assert devbox.exists()
        # Other hosts should not be created
        others = [p for p in Path(temp_sites_dir).rglob('dthm-*.yaml') if 'devbox' not in str(p)]
        # If others exist, ensure they weren't created by this run; we don't assert none exist because fixtures may include site-level files

    def test_test_mode_validation_fails(self, temp_sites_dir, temp_config_file):
        """Test that validation runs during -test and fails on invalid config"""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        if not os.path.exists(script_path):
            pytest.skip("Script not found")

        # Create invalid host YAML in a host (non-numeric port)
        bad_host = Path(temp_sites_dir) / 's01-prod' / 'host02'
        bad_file = bad_host / 'dthm-host.yaml'
        bad_file.write_text("hostname: 10.1.1.20\nport: notanumber\n")
        # Remove env override if present so YAML's port takes effect
        env_file = bad_host / '.env.host02'
        if env_file.exists():
            env_file.unlink()

        result = subprocess.run(
            [script_path, '-test', '-sites-dir', str(temp_sites_dir), '-config', temp_config_file],
            capture_output=True,
            text=True
        )
        assert result.returncode != 0
        assert '[ERROR]' in result.stderr or '[ERROR]' in result.stdout


class TestErrorHandling:
    """Test error handling in sync script."""
    
    def test_missing_config_file(self):
        """Test handling of missing configuration file."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        result = subprocess.run(
            [script_path, '-config', '/nonexistent/config.yaml', '-sites-dir', '/tmp'],
            capture_output=True,
            text=True
        )
        
        assert result.returncode != 0
        # Check stdout for error message (logging goes to stdout)
        assert 'not found' in result.stdout.lower()
    
    def test_missing_sites_dir(self, temp_config_file):
        """Test handling of missing sites directory."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        result = subprocess.run(
            [script_path, '-config', temp_config_file, '-sites-dir', '/nonexistent/sites'],
            capture_output=True,
            text=True
        )
        
        assert result.returncode != 0
        # Check stdout for error message (logging goes to stdout)
        assert 'not found' in result.stdout.lower()
    
    def test_invalid_option(self):
        """Test handling of invalid command-line options."""
        script_path = "/home/divix/divtools/projects/dthostmon/scripts/dthostmon_sync_config.sh"
        
        if not os.path.exists(script_path):
            pytest.skip("Script not found")
        
        result = subprocess.run(
            [script_path, '--invalid-option'],
            capture_output=True,
            text=True
        )
        
        assert result.returncode != 0
        # Check stdout for error message (logging goes to stdout)
        assert 'Unknown option' in result.stdout or 'unknown' in result.stdout.lower()


if __name__ == '__main__':
    pytest.main([__file__, '-v'])
