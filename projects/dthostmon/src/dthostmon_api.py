#!/usr/bin/env python3
"""
dthostmon API Server Entry Point
Last Updated: 11/14/2025 12:00:00 PM CDT

Starts the FastAPI REST API server for dthostmon.
"""

import sys
import argparse
from pathlib import Path
import uvicorn

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dthostmon.utils import Config, setup_logging
from dthostmon.models import DatabaseManager
from dthostmon.api import create_app


def main():
    """Start API server"""
    parser = argparse.ArgumentParser(description='dthostmon API Server')
    parser.add_argument('-c', '--config', default='config/dthostmon.yaml',
                       help='Path to configuration file')
    parser.add_argument('-e', '--env', default='.env',
                       help='Path to environment file')
    parser.add_argument('--host', default='0.0.0.0',
                       help='Server host (default: 0.0.0.0)')
    parser.add_argument('--port', type=int, default=None,
                       help='Server port (default: from config)')
    parser.add_argument('--debug', action='store_true',
                       help='Enable debug mode')
    
    args = parser.parse_args()
    
    # Load configuration
    config = Config(config_path=args.config, env_file=args.env)
    
    # Setup logging
    setup_logging(level='DEBUG' if args.debug else 'INFO')
    
    # Initialize database
    db_manager = DatabaseManager(config.database_url, echo=args.debug)
    
    # Get API configuration
    api_config = config.get('api', {})
    api_key = api_config.get('api_key')
    port = args.port or api_config.get('port', 8080)
    
    if not api_key:
        print("ERROR: API key not configured in config file or environment")
        sys.exit(1)
    
    # Create FastAPI app
    app = create_app(db_manager, api_key)
    
    # Start server
    print(f"\n{'=' * 70}")
    print(f"dthostmon API Server")
    print(f"{'=' * 70}")
    print(f"Listening on: http://{args.host}:{port}")
    print(f"API Docs: http://{args.host}:{port}/docs")
    print(f"Health Check: http://{args.host}:{port}/health")
    print(f"{'=' * 70}\n")
    
    uvicorn.run(
        app,
        host=args.host,
        port=port,
        log_level='debug' if args.debug else 'info'
    )


if __name__ == '__main__':
    main()
