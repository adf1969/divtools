#!/usr/bin/env python3
"""
dthostmon - Main CLI Entry Point
Last Updated: 11/14/2025 12:00:00 PM CDT

Command-line interface for running monitoring cycles and managing the system.
"""

import sys
import argparse
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dthostmon.utils import Config, setup_logging
from dthostmon.models import DatabaseManager, build_db_url
from dthostmon.core import MonitoringOrchestrator


def run_monitor(args):
    """Run monitoring cycle"""
    # Load configuration
    config = Config(config_path=args.config, env_file=args.env)
    
    # Setup logging
    setup_logging(
        level=config.log_level,
        log_file=args.log_file,
        json_format=args.json_log
    )
    
    # Initialize database
    db_manager = DatabaseManager(config.database_url, echo=args.debug)
    
    # Create tables if they don't exist
    if args.init_db:
        print("Initializing database schema...")
        db_manager.create_tables()
        print("✓ Database initialized")
        return
    
    # Initialize orchestrator
    orchestrator = MonitoringOrchestrator(config, db_manager)
    
    # Run monitoring cycle
    orchestrator.run_monitoring_cycle()


def review_config(args):
    """Review current configuration"""
    config = Config(config_path=args.config, env_file=args.env)
    
    print("\n" + "=" * 70)
    print("CURRENT CONFIGURATION")
    print("=" * 70 + "\n")
    
    config.print_config(mask_secrets=not args.show_secrets)
    
    print("\n" + "=" * 70)
    print(f"Configuration loaded from: {config.config_path}")
    print(f"Monitored hosts: {len(config.hosts)}")
    print("=" * 70 + "\n")


def setup_hosts(args):
    """Test and setup SSH connectivity for all hosts"""
    config = Config(config_path=args.config, env_file=args.env)
    setup_logging(level='INFO')
    
    from dthostmon.core.ssh_client import SSHClient
    
    print("\n" + "=" * 70)
    print("SSH HOST SETUP CHECK")
    print("=" * 70 + "\n")
    
    ssh_key = config.get('ssh.key_path')
    results = []
    
    for host in config.hosts:
        host_name = host['name']
        hostname = host['hostname']
        port = host.get('port', 22)
        user = host['user']
        
        print(f"Testing {host_name} ({user}@{hostname}:{port})...", end=' ')
        
        try:
            ssh_client = SSHClient(hostname, port, user, ssh_key, timeout=10)
            ssh_client.connect(retries=1)
            ssh_client.disconnect()
            
            print("✓ OK")
            results.append((host_name, 'success', None))
            
        except Exception as e:
            print(f"✗ FAILED: {e}")
            results.append((host_name, 'failed', str(e)))
    
    # Summary
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70 + "\n")
    
    successful = sum(1 for _, status, _ in results if status == 'success')
    failed = len(results) - successful
    
    print(f"Total Hosts: {len(results)}")
    print(f"Successful:  {successful}")
    print(f"Failed:      {failed}\n")
    
    if failed > 0:
        print("Failed hosts:")
        for name, status, error in results:
            if status == 'failed':
                print(f"  - {name}: {error}")
        print("\nPlease verify SSH keys and connectivity for failed hosts.")
        sys.exit(1)
    else:
        print("✓ All hosts reachable!")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='dthostmon - DivTools Host Monitor',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    
    # Global arguments
    parser.add_argument('-c', '--config', default='config/dthostmon.yaml',
                       help='Path to configuration file')
    parser.add_argument('-e', '--env', default='.env',
                       help='Path to environment file')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug mode')
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # Monitor command
    monitor_parser = subparsers.add_parser('monitor', help='Run monitoring cycle')
    monitor_parser.add_argument('--init-db', action='store_true',
                               help='Initialize database schema')
    monitor_parser.add_argument('--log-file', help='Log file path')
    monitor_parser.add_argument('--json-log', action='store_true',
                               help='Use JSON log format')
    monitor_parser.set_defaults(func=run_monitor)
    
    # Config command
    config_parser = subparsers.add_parser('config', help='Review configuration')
    config_parser.add_argument('--show-secrets', action='store_true',
                              help='Show unmasked secrets (use with caution)')
    config_parser.set_defaults(func=review_config)
    
    # Setup command
    setup_parser = subparsers.add_parser('setup', help='Test and setup SSH connectivity')
    setup_parser.set_defaults(func=setup_hosts)
    
    # Parse arguments
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(1)
    
    # Execute command
    try:
        args.func(args)
    except KeyboardInterrupt:
        print("\nInterrupted by user")
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.debug:
            raise
        sys.exit(1)


if __name__ == '__main__':
    main()
