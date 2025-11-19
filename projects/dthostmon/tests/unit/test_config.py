"""
Unit tests for configuration module
Last Updated: 11/14/2025 12:00:00 PM CDT
"""

import pytest
from dthostmon.utils import Config, ConfigurationError


def test_config_loads_successfully(test_config_file, test_env_file):
    """Test that configuration loads from YAML file"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    assert config is not None
    assert config.get('global.log_level') == 'DEBUG'
    assert config.get('database.host') == 'localhost'


def test_config_env_var_substitution(test_config_file, test_env_file):
    """Test environment variable substitution"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    # Database URL should have substituted env vars
    assert 'localhost' in config.database_url
    assert 'dthostmon_test' in config.database_url


def test_config_dot_notation(test_config_file, test_env_file):
    """Test dot notation for accessing nested config"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    assert config.get('email.smtp_host') == 'smtp.example.com'
    assert config.get('email.smtp_port') == 587
    assert config.get('api.port') == 8080


def test_config_default_values(test_config_file, test_env_file):
    """Test default values for missing keys"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    assert config.get('nonexistent.key', 'default') == 'default'
    assert config.get('another.missing.key', 123) == 123


def test_config_hosts_property(test_config_file, test_env_file):
    """Test hosts property returns enabled hosts"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    hosts = config.hosts
    assert len(hosts) == 1
    assert hosts[0]['name'] == 'test-host-1'
    assert hosts[0]['enabled'] is True


def test_config_invalid_file():
    """Test that missing config file raises error"""
    with pytest.raises(ConfigurationError):
        Config(config_path='/nonexistent/config.yaml')


def test_config_log_level_property(test_config_file, test_env_file):
    """Test log_level property"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    assert config.log_level == 'DEBUG'


def test_get_host_report_frequency_host_override(test_config_file, test_env_file):
    """Test report frequency with host-level override"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    host = {
        'name': 'test-host',
        'site': 's01-test',
        'report_frequency': 'hourly'  # Host override
    }
    
    frequency = config.get_host_report_frequency(host)
    assert frequency == 'hourly'


def test_get_host_report_frequency_site_override(test_config_file, test_env_file):
    """Test report frequency with site-level override (no host override)"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    # Mock site configuration with frequency
    config._data['sites'] = {
        's01-test': {'report_frequency': 'weekly'}
    }
    config._data['global'] = {'report_frequency': 'daily'}
    
    host = {
        'name': 'test-host',
        'site': 's01-test'
        # No host-level report_frequency
    }
    
    frequency = config.get_host_report_frequency(host)
    assert frequency == 'weekly'


def test_get_host_report_frequency_global_default(test_config_file, test_env_file):
    """Test report frequency falls back to global default"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    config._data['global'] = {'report_frequency': 'daily'}
    
    host = {
        'name': 'test-host'
        # No site, no host-level frequency
    }
    
    frequency = config.get_host_report_frequency(host)
    assert frequency == 'daily'


def test_get_resource_thresholds_with_site(test_config_file, test_env_file):
    """Test resource thresholds with site-specific configuration"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    config._data['sites'] = {
        's01-test': {
            'resource_thresholds': {
                'health': '0-25',
                'info': '26-55',
                'warning': '56-84',
                'critical': '85-100'
            }
        }
    }
    
    thresholds = config.get_resource_thresholds(site='s01-test')
    
    assert thresholds['health'] == (0, 25)
    assert thresholds['info'] == (26, 55)
    assert thresholds['warning'] == (56, 84)
    assert thresholds['critical'] == (85, 100)


def test_get_resource_thresholds_global(test_config_file, test_env_file):
    """Test resource thresholds fall back to global configuration"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    config._data['global'] = {
        'resource_thresholds': {
            'health': '0-30',
            'info': '31-60',
            'warning': '61-89',
            'critical': '90-100'
        }
    }
    
    thresholds = config.get_resource_thresholds()
    
    assert thresholds['health'] == (0, 30)
    assert thresholds['info'] == (31, 60)
    assert thresholds['warning'] == (61, 89)
    assert thresholds['critical'] == (90, 100)


def test_parse_thresholds_string_format(test_config_file, test_env_file):
    """Test threshold parsing from string format"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    threshold_config = {
        'health': '0-30',
        'warning': '61-89',
        'critical': '90-100'
    }
    
    parsed = config._parse_thresholds(threshold_config)
    
    assert parsed['health'] == (0, 30)
    assert parsed['warning'] == (61, 89)
    assert parsed['critical'] == (90, 100)


def test_parse_thresholds_tuple_format(test_config_file, test_env_file):
    """Test threshold parsing when already in tuple format"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    threshold_config = {
        'health': (0, 30),
        'warning': (61, 89)
    }
    
    parsed = config._parse_thresholds(threshold_config)
    
    assert parsed['health'] == (0, 30)
    assert parsed['warning'] == (61, 89)


def test_sites_property_returns_unique_list(test_config_file, test_env_file):
    """Test sites property returns unique site identifiers"""
    config = Config(config_path=test_config_file, env_file=test_env_file)
    
    config._data['hosts'] = [
        {'name': 'host1', 'site': 's01-chicago'},
        {'name': 'host2', 'site': 's01-chicago'},
        {'name': 'host3', 'site': 's02-austin'},
        {'name': 'host4'}  # No site
    ]
    
    sites = config.sites
    
    assert len(sites) == 2
    assert 's01-chicago' in sites
    assert 's02-austin' in sites
