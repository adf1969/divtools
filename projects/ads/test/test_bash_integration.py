#!/home/divix/divtools/scripts/venvs/dtpyutil/bin/python3
"""
Bash Integration Tests for dt_ads_native.sh

Tests that verify the dt_ads_native.sh wrapper script can be executed from bash
without AttributeError or module import failures.

These tests expose integration errors that unit tests miss - the gap between
testing Python code in isolation vs testing actual bash script execution.

Last Updated: 01/15/2026 8:35:00 PM CST
"""

import pytest
import subprocess
import os
from pathlib import Path


class TestBashIntegration:
    """Test suite for bash script integration"""
    
    @pytest.fixture
    def script_path(self):
        """Get path to the dt_ads_native.sh wrapper script"""
        divtools = os.getenv('DIVTOOLS', '/home/divix/divtools')
        script = Path(divtools) / 'scripts' / 'ads' / 'dt_ads_native.sh'
        assert script.exists(), f"Script not found at {script}"
        return script
    
    @pytest.fixture
    def divtools_env(self):
        """Set up environment with DIVTOOLS variable"""
        divtools = os.getenv('DIVTOOLS', '/home/divix/divtools')
        env = os.environ.copy()
        env['DIVTOOLS'] = divtools
        return env
    
    def test_script_help_flag_no_errors(self, script_path, divtools_env):
        """
        Test that dt_ads_native.sh --help works without AttributeError
        
        This is the main integration test that catches the issue reported:
        'module dtpyutil.menu.dtpmenu has no attribute menu'
        
        If this test fails, it means the Python script is trying to use
        dtpmenu incorrectly (as a module instead of a class).
        """
        # Run script with --help flag (safe, non-interactive)
        result = subprocess.run(
            [str(script_path), '--help'],
            capture_output=True,
            text=True,
            timeout=5,
            env=divtools_env
        )
        
        # Should succeed with exit code 0
        assert result.returncode == 0, f"Script failed with exit code {result.returncode}\nStderr: {result.stderr}"
        
        # Should show help text
        assert 'Samba AD DC Native Setup' in result.stdout, "Help text not found in output"
        assert '--test' in result.stdout, "--test flag not documented"
        assert '--debug' in result.stdout, "--debug flag not documented"
        
        # Most important: NO AttributeError in output
        assert 'AttributeError' not in result.stderr, f"AttributeError found in stderr: {result.stderr}"
        assert 'has no attribute' not in result.stderr, f"Module attribute error found: {result.stderr}"
        assert 'ImportError' not in result.stderr, f"Import error found: {result.stderr}"
    
    def test_script_test_flag_no_errors(self, script_path, divtools_env):
        """
        Test that dt_ads_native.sh -test flag is recognized without AttributeError
        
        The key assertion is that no AttributeError is raised during initialization,
        which would indicate the menu system is trying to use dtpmenu incorrectly.
        """
        # Run with a very short timeout - we just need to see if it starts without error
        # The menu will hang trying to render in a pipe, so we expect timeout
        # But the important thing is NO AttributeError in stderr before timeout
        try:
            result = subprocess.run(
                [str(script_path), '-test'],
                input='',
                capture_output=True,
                text=True,
                timeout=2,
                env=divtools_env
            )
        except subprocess.TimeoutExpired as e:
            # Timeout is expected when TUI tries to render
            # Check that there's no AttributeError in stderr
            stderr = e.stderr if isinstance(e.stderr, str) else (e.stderr.decode() if e.stderr else "")
            assert 'AttributeError' not in stderr, f"AttributeError before timeout: {stderr}"
            assert 'has no attribute' not in stderr, f"Module error before timeout: {stderr}"
            # If we got here, the test passes (initialization worked without AttributeError)
            return
        
        # If no timeout, also check for AttributeError
        assert 'AttributeError' not in result.stderr, f"AttributeError in test mode: {result.stderr}"
        assert 'has no attribute' not in result.stderr, f"Module error in test mode: {result.stderr}"
    
    def test_script_debug_flag_no_errors(self, script_path, divtools_env):
        """
        Test that dt_ads_native.sh -debug flag is recognized without AttributeError
        """
        try:
            result = subprocess.run(
                [str(script_path), '-debug'],
                input='',
                capture_output=True,
                text=True,
                timeout=2,
                env=divtools_env
            )
        except subprocess.TimeoutExpired as e:
            # Timeout is expected when TUI tries to render in a pipe
            stderr = e.stderr if isinstance(e.stderr, str) else (e.stderr.decode() if e.stderr else "")
            assert 'AttributeError' not in stderr, f"AttributeError in debug mode: {stderr}"
            assert 'has no attribute' not in stderr, f"Module error in debug mode: {stderr}"
            return
        
        # If no timeout, also check for AttributeError
        assert 'AttributeError' not in result.stderr, f"AttributeError in debug mode: {result.stderr}"
        assert 'has no attribute' not in result.stderr, f"Module error in debug mode: {result.stderr}"
    
    def test_python_import_dtpyutil(self, divtools_env):
        """
        Test that the dtpyutil module can be imported from the dtpyutil venv
        
        Uses the dtpyutil venv Python interpreter (which has textual installed)
        instead of the system python3.
        """
        divtools = divtools_env.get('DIVTOOLS', '/home/divix/divtools')
        dtpyutil_venv_python = Path(divtools) / 'scripts' / 'venvs' / 'dtpyutil' / 'bin' / 'python3'
        dtpyutil_src = Path(divtools) / 'projects' / 'dtpyutil' / 'src'
        
        assert dtpyutil_src.exists(), f"dtpyutil source not found at {dtpyutil_src}"
        assert dtpyutil_venv_python.exists(), f"dtpyutil Python not found at {dtpyutil_venv_python}"
        
        # Run import test with dtpyutil venv Python (has textual installed)
        test_code = f"""
import sys
from pathlib import Path

dtpyutil_src = Path('{dtpyutil_src}')
sys.path.insert(0, str(dtpyutil_src))

try:
    from dtpyutil.menu.dtpmenu import DtpMenuApp
    print("SUCCESS: DtpMenuApp imported successfully")
    sys.exit(0)
except ImportError as e:
    print(f"FAILED: Could not import DtpMenuApp: {{e}}")
    sys.exit(1)
"""
        
        result = subprocess.run(
            [str(dtpyutil_venv_python), '-c', test_code],
            capture_output=True,
            text=True,
            timeout=5,
            env=divtools_env
        )
        
        assert result.returncode == 0, f"Import test failed: {result.stdout}{result.stderr}"
        assert 'SUCCESS' in result.stdout, f"Import test did not succeed: {result.stdout}"
    
    def test_divtools_path_resolution(self, divtools_env, script_path):
        """
        Test that DIVTOOLS environment variable is properly resolved
        
        The script needs to find:
        - projects/dtpyutil/src/dtpyutil/menu/dtpmenu.py
        
        This test verifies the path resolution works correctly.
        """
        divtools = divtools_env.get('DIVTOOLS', '/home/divix/divtools')
        divtools_path = Path(divtools)
        
        # Check that divtools directory exists
        assert divtools_path.exists(), f"DIVTOOLS directory not found: {divtools_path}"
        
        # Check that dtpyutil project exists
        dtpyutil_project = divtools_path / 'projects' / 'dtpyutil'
        assert dtpyutil_project.exists(), f"dtpyutil project not found at {dtpyutil_project}"
        
        # Check that menu source exists
        menu_module = dtpyutil_project / 'src' / 'dtpyutil' / 'menu' / 'dtpmenu.py'
        assert menu_module.exists(), f"Menu module not found at {menu_module}"
        
        # Check that wrapper script exists
        assert script_path.exists(), f"Wrapper script not found at {script_path}"


class TestKeyLessons:
    """
    Documentation of lessons learned from the integration test gap
    
    These tests demonstrate why unit tests alone are insufficient
    and why bash integration tests are critical.
    """
    
    def test_unit_tests_miss_cli_integration_errors(self):
        """
        LESSON: Unit tests that only test Python code in isolation
        will NOT catch errors that occur during actual script execution.
        
        Example: The original issue was that the script imported dtpmenu
        as a module and called dtpmenu.menu() - a method that doesn't exist.
        
        The 16 unit tests all passed because:
        1. Tests imported the ADSNativeApp class directly
        2. Tests mocked/stubbed the menu calls
        3. Tests never actually executed the menu methods
        
        But bash execution failed immediately because:
        1. The script wrapper called the Python code
        2. Python code tried to use dtpmenu.menu() 
        3. That method doesn't exist - AttributeError!
        
        FIX: Add bash integration tests that spawn the script as a subprocess
        to catch real-world execution errors.
        """
        # This is a documentation test - the presence of this test file
        # and the previous tests demonstrate the solution.
        assert True
    
    def test_environment_variable_propagation(self):
        """
        LESSON: Environment variables must be properly propagated from
        bash wrapper to Python script to Python subprocesses.
        
        The wrapper script needs to:
        1. Detect/set DIVTOOLS environment variable
        2. Export DIVTOOLS so child processes inherit it
        3. Call Python script with DIVTOOLS in environment
        
        The Python script needs to:
        1. Read DIVTOOLS from os.getenv()
        2. Use it to locate dtpyutil
        3. Ensure DIVTOOLS is available to any subprocesses
        """
        divtools = os.getenv('DIVTOOLS', '/home/divix/divtools')
        assert isinstance(divtools, str), "DIVTOOLS should be a string"
        assert len(divtools) > 0, "DIVTOOLS should not be empty"
        # Verify it points to an actual directory
        assert Path(divtools).exists(), f"DIVTOOLS path does not exist: {divtools}"
