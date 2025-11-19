"""
Unit tests for SSH client module
Last Updated: 11/15/2025 11:30:00 AM CDT
"""

import pytest
from unittest.mock import Mock, patch, MagicMock, call
from pathlib import Path
import paramiko
from dthostmon.core.ssh_client import SSHClient, SSHConnectionError, LogRetrievalError


@pytest.fixture
def ssh_config():
    """SSH configuration for testing"""
    return {
        'hostname': '192.168.1.100',
        'port': 22,
        'username': 'testuser',
        'key_path': '/tmp/test_key',
        'timeout': 10
    }


def test_ssh_client_initialization(ssh_config):
    """Test SSHClient initialization"""
    client = SSHClient(
        hostname=ssh_config['hostname'],
        port=ssh_config['port'],
        username=ssh_config['username'],
        key_path=ssh_config['key_path'],
        timeout=ssh_config['timeout']
    )
    
    assert client.hostname == '192.168.1.100'
    assert client.port == 22
    assert client.username == 'testuser'
    assert client.key_path == '/tmp/test_key'
    assert client.timeout == 10
    assert client.connected is False


@patch('paramiko.Ed25519Key.from_private_key_file')
@patch('paramiko.SSHClient.connect')
def test_ssh_client_connect_success(mock_connect, mock_key, ssh_config, mock_ssh_key):
    """Test successful SSH connection"""
    mock_key.return_value = Mock()
    
    client = SSHClient(**ssh_config)
    client.key_path = mock_ssh_key
    
    result = client.connect(retries=1)
    
    assert result is True
    assert client.connected is True
    mock_connect.assert_called_once()


@patch('paramiko.Ed25519Key.from_private_key_file')
@patch('paramiko.SSHClient.connect')
def test_ssh_client_connect_key_not_found(mock_connect, mock_key, ssh_config):
    """Test SSH connection fails when key file doesn't exist"""
    client = SSHClient(**ssh_config)
    
    with pytest.raises(SSHConnectionError, match="SSH key not found"):
        client.connect(retries=1)


@patch('paramiko.Ed25519Key.from_private_key_file')
@patch('paramiko.SSHClient.connect')
@patch('time.sleep')
def test_ssh_client_connect_retry_logic(mock_sleep, mock_connect, mock_key, 
                                        ssh_config, mock_ssh_key):
    """Test SSH connection retry with exponential backoff"""
    mock_key.return_value = Mock()
    # First two attempts fail, third succeeds
    mock_connect.side_effect = [
        paramiko.AuthenticationException("Auth failed"),
        paramiko.SSHException("Connection failed"),
        None
    ]
    
    client = SSHClient(**ssh_config)
    client.key_path = mock_ssh_key
    
    result = client.connect(retries=3)
    
    assert result is True
    assert client.connected is True
    assert mock_connect.call_count == 3
    assert mock_sleep.call_count == 2
    # Check exponential backoff: 2^0=1s, 2^1=2s
    mock_sleep.assert_any_call(1)
    mock_sleep.assert_any_call(2)


@patch('paramiko.Ed25519Key.from_private_key_file')
@patch('paramiko.SSHClient.connect')
@patch('time.sleep')
def test_ssh_client_connect_fails_after_retries(mock_sleep, mock_connect, mock_key,
                                                ssh_config, mock_ssh_key):
    """Test SSH connection fails after all retries exhausted"""
    mock_key.return_value = Mock()
    mock_connect.side_effect = paramiko.AuthenticationException("Auth failed")
    
    client = SSHClient(**ssh_config)
    client.key_path = mock_ssh_key
    
    with pytest.raises(SSHConnectionError, match="Failed to connect"):
        client.connect(retries=3)
    
    assert client.connected is False
    assert mock_connect.call_count == 3


@patch('paramiko.SSHClient.close')
def test_ssh_client_disconnect(mock_close, ssh_config):
    """Test SSH disconnection"""
    client = SSHClient(**ssh_config)
    client.client = Mock()
    client.connected = True
    
    client.disconnect()
    
    assert client.connected is False
    mock_close.assert_called_once()


def test_ssh_client_disconnect_when_not_connected(ssh_config):
    """Test disconnect when client not connected"""
    client = SSHClient(**ssh_config)
    client.connected = False
    client.client = None
    
    # Should not raise an exception
    client.disconnect()
    assert client.connected is False


def test_execute_command_not_connected(ssh_config):
    """Test execute_command raises error when not connected"""
    client = SSHClient(**ssh_config)
    client.connected = False
    
    with pytest.raises(SSHConnectionError, match="Not connected"):
        client.execute_command("ls -la")


@patch('paramiko.SSHClient.exec_command')
def test_execute_command_success(mock_exec, ssh_config):
    """Test successful command execution"""
    # Mock the channel and file objects
    mock_channel = Mock()
    mock_channel.recv_exit_status.return_value = 0
    
    mock_stdout = Mock()
    mock_stdout.channel = mock_channel
    mock_stdout.read.return_value = b"file1.txt\nfile2.txt\n"
    
    mock_stderr = Mock()
    mock_stderr.read.return_value = b""
    
    mock_stdin = Mock()
    mock_exec.return_value = (mock_stdin, mock_stdout, mock_stderr)
    
    client = SSHClient(**ssh_config)
    client.client = Mock()
    client.connected = True
    
    stdout, stderr, exit_code = client.execute_command("ls -la")
    
    assert stdout == "file1.txt\nfile2.txt\n"
    assert stderr == ""
    assert exit_code == 0


@patch('paramiko.SSHClient.exec_command')
def test_execute_command_with_error(mock_exec, ssh_config):
    """Test command execution with non-zero exit code"""
    mock_channel = Mock()
    mock_channel.recv_exit_status.return_value = 1
    
    mock_stdout = Mock()
    mock_stdout.channel = mock_channel
    mock_stdout.read.return_value = b""
    
    mock_stderr = Mock()
    mock_stderr.read.return_value = b"Permission denied"
    
    mock_stdin = Mock()
    mock_exec.return_value = (mock_stdin, mock_stdout, mock_stderr)
    
    client = SSHClient(**ssh_config)
    client.client = Mock()
    client.connected = True
    
    stdout, stderr, exit_code = client.execute_command("cat /etc/shadow")
    
    assert stdout == ""
    assert stderr == "Permission denied"
    assert exit_code == 1


@patch('paramiko.SSHClient.exec_command')
def test_execute_command_timeout(mock_exec, ssh_config):
    """Test command execution with timeout"""
    mock_exec.side_effect = Exception("Command timed out")
    
    client = SSHClient(**ssh_config)
    client.client = Mock()
    client.connected = True
    
    with pytest.raises(LogRetrievalError, match="Failed to execute command"):
        client.execute_command("sleep 100", timeout=1)


def test_retrieve_log_file_not_connected(ssh_config):
    """Test retrieve_log_file raises error when not connected"""
    client = SSHClient(**ssh_config)
    client.connected = False
    
    with pytest.raises(SSHConnectionError, match="Not connected"):
        client.retrieve_log_file("/var/log/syslog")


@patch.object(SSHClient, 'execute_command')
def test_retrieve_log_file_success(mock_exec, ssh_config):
    """Test successful log file retrieval"""
    # First call checks if file exists
    mock_exec.side_effect = [
        ("OK", "", 0),  # File exists check
        ("Nov 14 12:00:01 test CRON[1234]: (root) CMD\nNov 14 12:00:02 test test", "", 0)  # File contents
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    result = client.retrieve_log_file("/var/log/syslog")
    
    assert result['path'] == "/var/log/syslog"
    assert result['content'] == "Nov 14 12:00:01 test CRON[1234]: (root) CMD\nNov 14 12:00:02 test test"
    assert result['line_count'] == 2
    assert result['file_size'] > 0
    assert result['hash'] is not None
    assert result['error'] is None


@patch.object(SSHClient, 'execute_command')
def test_retrieve_log_file_not_found(mock_exec, ssh_config):
    """Test log file retrieval when file not found"""
    mock_exec.return_value = ("FAIL", "", 1)  # File doesn't exist
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    result = client.retrieve_log_file("/var/log/nonexistent.log")
    
    assert result['path'] == "/var/log/nonexistent.log"
    assert result['content'] is None
    assert result['hash'] is None
    assert result['error'] == 'File not accessible'


@patch.object(SSHClient, 'execute_command')
def test_retrieve_log_file_read_error(mock_exec, ssh_config):
    """Test log file retrieval when read fails"""
    mock_exec.side_effect = [
        ("OK", "", 0),  # File exists check
        Exception("Read failed")  # File read fails
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    with pytest.raises(LogRetrievalError, match="Log retrieval failed"):
        client.retrieve_log_file("/var/log/syslog")


@patch.object(SSHClient, 'execute_command')
def test_retrieve_multiple_logs_basic(mock_exec, ssh_config):
    """Test retrieving multiple log files"""
    mock_exec.side_effect = [
        ("OK", "", 0),  # syslog exists
        ("syslog content", "", 0),  # syslog contents
        ("OK", "", 0),  # auth.log exists
        ("auth.log content", "", 0),  # auth.log contents
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    results = client.retrieve_multiple_logs(["/var/log/syslog", "/var/log/auth.log"])
    
    assert len(results) == 2
    assert results[0]['path'] == "/var/log/syslog"
    assert results[0]['content'] == "syslog content"
    assert results[1]['path'] == "/var/log/auth.log"
    assert results[1]['content'] == "auth.log content"


@patch.object(SSHClient, 'execute_command')
def test_retrieve_multiple_logs_with_glob_pattern(mock_exec, ssh_config):
    """Test retrieving logs with glob patterns"""
    mock_exec.side_effect = [
        # Glob expansion for /home/*/test*.log
        ("/home/user1/test.log\n/home/user2/test.log", "", 0),
        # Read first expanded file
        ("OK", "", 0),
        ("test1 logs", "", 0),
        # Read second expanded file
        ("OK", "", 0),
        ("test2 logs", "", 0),
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    results = client.retrieve_multiple_logs(["/home/*/test*.log"])
    
    assert len(results) == 2
    assert results[0]['path'] == "/home/user1/test.log"
    assert results[1]['path'] == "/home/user2/test.log"


@patch.object(SSHClient, 'execute_command')
def test_retrieve_multiple_logs_glob_no_match(mock_exec, ssh_config):
    """Test glob pattern with no matches"""
    mock_exec.return_value = ("", "", 2)  # No files found
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    results = client.retrieve_multiple_logs(["/home/*/nonexistent*.log"])
    
    assert len(results) == 0


@patch.object(SSHClient, 'execute_command')
def test_retrieve_multiple_logs_partial_failure(mock_exec, ssh_config):
    """Test retrieving multiple logs when some fail"""
    mock_exec.side_effect = [
        ("OK", "", 0),  # syslog exists
        ("syslog content", "", 0),  # syslog contents
        ("FAIL", "", 1),  # auth.log doesn't exist
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    results = client.retrieve_multiple_logs(["/var/log/syslog", "/var/log/auth.log"])
    
    assert len(results) == 2
    assert results[0]['content'] == "syslog content"
    assert results[1]['error'] == 'File not accessible'


def test_ssh_client_context_manager(mock_ssh_key):
    """Test SSHClient as context manager"""
    ssh_config = {
        'hostname': '192.168.1.100',
        'port': 22,
        'username': 'testuser',
        'key_path': mock_ssh_key,
        'timeout': 10
    }
    
    with patch('paramiko.Ed25519Key.from_private_key_file'):
        with patch('paramiko.SSHClient.connect'):
            with patch('paramiko.SSHClient.close'):
                with SSHClient(**ssh_config) as client:
                    assert client.connected is True
                
                # After exiting context, should be disconnected
                assert client.connected is False


@patch.object(SSHClient, 'execute_command')
def test_log_file_hash_consistency(mock_exec, ssh_config):
    """Test that log file hash is consistent for same content"""
    log_content = "Test log line 1\nTest log line 2\n"
    mock_exec.side_effect = [
        ("OK", "", 0),  # File exists
        (log_content, "", 0),  # File contents
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    result = client.retrieve_log_file("/var/log/test.log")
    hash1 = result['hash']
    
    # Retrieve same file again
    mock_exec.side_effect = [
        ("OK", "", 0),  # File exists
        (log_content, "", 0),  # Same contents
    ]
    
    result2 = client.retrieve_log_file("/var/log/test.log")
    hash2 = result2['hash']
    
    assert hash1 == hash2


@patch.object(SSHClient, 'execute_command')
def test_log_file_utf8_handling(mock_exec, ssh_config):
    """Test log file retrieval with UTF-8 special characters"""
    log_content = "Test with Unicode: café, naïve, 中文\n"
    mock_exec.side_effect = [
        ("OK", "", 0),  # File exists
        (log_content, "", 0),  # File with UTF-8 content
    ]
    
    client = SSHClient(**ssh_config)
    client.connected = True
    
    result = client.retrieve_log_file("/var/log/test.log")
    
    assert result['content'] == log_content
    assert 'café' in result['content']
    assert result['file_size'] > 0
