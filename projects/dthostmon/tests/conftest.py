"""
Pytest fixtures and test configuration
Last Updated: 11/14/2025 12:00:00 PM CDT

Shared fixtures for unit and integration tests.
"""

import pytest
import os
import tempfile
from pathlib import Path

# Add src to path for test imports
import sys
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from dthostmon.models import DatabaseManager
from dthostmon.utils import Config


@pytest.fixture(scope='session')
def test_config_file(tmp_path_factory):
    """Create temporary configuration file for testing"""
    config_dir = tmp_path_factory.mktemp('config')
    config_file = config_dir / 'dthostmon.yaml'
    
    config_content = """
global:
  log_level: DEBUG
  monitor_interval: 3600
  max_concurrent_hosts: 2

database:
  host: localhost
  port: 5432
  name: dthostmon_test
  user: test_user
  password: test_password

email:
  smtp_host: smtp.example.com
  smtp_port: 587
  smtp_user: test@example.com
  smtp_password: test_password
  from_address: dthostmon@example.com
  alert_recipients:
    - admin@example.com
  use_tls: true

ai:
  primary_model: grok
  fallback_model: ollama
  grok:
    api_key: test_grok_key
    api_url: https://api.x.ai/v1
    model_name: grok-beta
  ollama:
    host: http://localhost:11434
    model: llama3.1

ssh:
  key_path: /tmp/test_key
  timeout: 10

api:
  port: 8080
  api_key: test_api_key

hosts:
  - name: test-host-1
    hostname: 192.168.1.100
    port: 22
    user: testuser
    enabled: true
    logs:
      - /var/log/syslog
      - /var/log/auth.log
    tags:
      - test
      - production
"""
    
    config_file.write_text(config_content)
    return str(config_file)


@pytest.fixture(scope='session')
def test_env_file(tmp_path_factory):
    """Create temporary .env file for testing"""
    env_dir = tmp_path_factory.mktemp('env')
    env_file = env_dir / '.env'
    
    env_content = """
DB_HOST=localhost
DB_PORT=5432
DB_NAME=dthostmon_test
DB_USER=test_user
DB_PASSWORD=test_password
SMTP_HOST=smtp.example.com
SMTP_PORT=587
SMTP_USER=test@example.com
SMTP_PASSWORD=test_password
"""
    
    env_file.write_text(env_content)
    return str(env_file)


@pytest.fixture
def config(test_config_file, test_env_file):
    """Configuration fixture"""
    return Config(config_path=test_config_file, env_file=test_env_file)


@pytest.fixture(scope='function')
def db_manager():
    """Database manager fixture with in-memory SQLite for testing"""
    # Use SQLite in-memory database for unit tests
    db_url = "sqlite:///:memory:"
    manager = DatabaseManager(db_url, echo=False)
    manager.create_tables()
    
    yield manager
    
    # Cleanup
    manager.drop_tables()


@pytest.fixture
def sample_host_data():
    """Sample host data for testing"""
    return {
        'id': 1,
        'name': 'test-host',
        'hostname': '192.168.1.100',
        'port': 22,
        'user': 'testuser',
        'logs': ['/var/log/syslog', '/var/log/auth.log'],
        'tags': ['test', 'production']
    }


@pytest.fixture
def sample_log_data():
    """Sample log data for testing"""
    return [
        {
            'path': '/var/log/syslog',
            'content': 'Nov 14 12:00:01 test-host CRON[1234]: (root) CMD (test)',
            'hash': 'abc123def456',
            'line_count': 1,
            'file_size': 100,
            'retrieved_at': '2025-11-14T12:00:00'
        },
        {
            'path': '/var/log/auth.log',
            'content': 'Nov 14 12:00:02 test-host sshd[5678]: Accepted publickey for user',
            'hash': 'def456ghi789',
            'line_count': 1,
            'file_size': 150,
            'retrieved_at': '2025-11-14T12:00:01'
        }
    ]


@pytest.fixture
def mock_ssh_key(tmp_path):
    """Create mock SSH key file for testing"""
    key_file = tmp_path / "id_ed25519"
    key_file.write_text("-----BEGIN OPENSSH PRIVATE KEY-----\ntest_key_content\n-----END OPENSSH PRIVATE KEY-----\n")
    key_file.chmod(0o600)
    return str(key_file)
