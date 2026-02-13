#!/usr/bin/env python3
"""
MCP-Based Host Monitoring Application

This is a working example of using MCPs (Model Context Protocol) to build
a host monitoring system. It demonstrates:

1. Loading host configuration from YAML
2. Connecting to MCP servers
3. Using MCPs to collect data
4. Analyzing with an LLM
5. Storing results in audit log
6. Managing credentials securely

Usage:
    python mcp_host_monitor.py --config config/monitoring.yaml
    python mcp_host_monitor.py --analyze production-db
    python mcp_host_monitor.py --report  # Show recent findings
"""

import asyncio
import json
import yaml
import argparse
import sys
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Any, Optional
import os
from dataclasses import dataclass
import logging

# MCP and LLM libraries
try:
    from anthropic import Anthropic
except ImportError:
    print("ERROR: anthropic library not installed")
    print("Install with: pip install anthropic")
    sys.exit(1)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


@dataclass
class HostConfig:
    """Host configuration"""
    name: str
    ip: str
    ssh_user: str
    ssh_key: Optional[str] = None
    services: List[str] = None
    critical: bool = False
    check_interval: str = "daily"
    
    def __post_init__(self):
        if self.services is None:
            self.services = []


class CredentialManager:
    """Manage credentials securely"""
    
    def __init__(self, config_dir: Path = Path("config")):
        self.config_dir = config_dir
        self.env_prefix = "DIVTOOLS_"
    
    def get_credential(self, key: str, default: Optional[str] = None) -> Optional[str]:
        """
        Get credential from environment or file.
        
        Looks in order:
        1. Environment variable (DIVTOOLS_<KEY>)
        2. Encrypted credentials file (future)
        3. Default value
        """
        env_key = f"{self.env_prefix}{key.upper()}"
        
        # Check environment first
        if env_key in os.environ:
            return os.environ[env_key]
        
        # Check credentials file (if encrypted in future)
        creds_file = self.config_dir / "credentials.yaml"
        if creds_file.exists():
            try:
                with open(creds_file) as f:
                    creds = yaml.safe_load(f)
                    if key in creds:
                        return creds[key]
            except Exception as e:
                logger.warning(f"Could not read credentials file: {e}")
        
        return default
    
    def validate_required(self, required_keys: List[str]) -> bool:
        """Validate that required credentials are available"""
        missing = []
        for key in required_keys:
            if not self.get_credential(key):
                missing.append(key)
        
        if missing:
            logger.error(f"Missing required credentials: {', '.join(missing)}")
            logger.error(f"Set environment variables: {self.env_prefix}" + 
                        f", {self.env_prefix}".join(missing))
            return False
        return True


class MCPHostMonitor:
    """Host monitoring system using MCPs"""
    
    def __init__(self, config_file: str):
        """Initialize monitor with configuration"""
        self.config_file = Path(config_file)
        self.config = self._load_config()
        self.hosts: Dict[str, HostConfig] = self._parse_hosts()
        self.audit_log = Path(self.config.get('audit_log_path', 
                             '/var/log/divtools/monitor/audit/monitor.log'))
        
        # Initialize LLM client
        api_key = os.getenv('ANTHROPIC_API_KEY')
        if not api_key:
            raise ValueError("ANTHROPIC_API_KEY environment variable not set")
        self.llm = Anthropic(api_key=api_key)
        
        # Credential manager
        self.creds = CredentialManager()
        
        logger.info(f"Initialized monitor with {len(self.hosts)} hosts")
    
    def _load_config(self) -> dict:
        """Load YAML configuration"""
        if not self.config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_file}")
        
        with open(self.config_file) as f:
            config = yaml.safe_load(f)
        
        logger.info(f"Loaded configuration from {self.config_file}")
        return config
    
    def _parse_hosts(self) -> Dict[str, HostConfig]:
        """Parse host configuration"""
        hosts = {}
        
        for hostname, host_config in self.config.get('hosts', {}).items():
            try:
                hosts[hostname] = HostConfig(
                    name=hostname,
                    ip=host_config.get('ip'),
                    ssh_user=host_config.get('ssh_user', 'root'),
                    ssh_key=host_config.get('ssh_key'),
                    services=host_config.get('services', []),
                    critical=host_config.get('critical', False),
                    check_interval=host_config.get('check_interval', 'daily')
                )
            except Exception as e:
                logger.error(f"Error parsing host {hostname}: {e}")
        
        return hosts
    
    def simulate_collect_host_changes(self, hostname: str) -> Dict[str, Any]:
        """
        Simulate collecting changes from a host.
        
        In a real implementation, this would:
        1. Connect to SSH MCP server
        2. Execute commands on remote host
        3. Parse and return results
        
        For now, we return mock data for demonstration.
        """
        logger.info(f"Collecting changes from {hostname}...")
        
        # In real implementation, would call SSH MCP like:
        # result = await self.mcp_sessions['ssh'].call_tool(
        #     'execute_command',
        #     {'host': hostname, 'command': 'tail -50 /var/log/divtools/monitor/history/*.latest'}
        # )
        
        # Mock data for demonstration
        changes = {
            'hostname': hostname,
            'collection_time': datetime.utcnow().isoformat(),
            'command_history': [
                "2025-11-11 14:30:22 sudo systemctl status postgresql",
                "2025-11-11 14:31:15 docker ps",
                "2025-11-11 14:32:10 apt update",
                "2025-11-11 14:33:45 nginx -t"
            ],
            'apt_changes': [
                "postgresql-15 (15.1-1.pgdg22.04+1)",
                "docker.io (25.0.1-1)"
            ],
            'docker_integrity': "verified",
            'system_errors': [
                "systemd[1]: Started Network Name Resolution.",
                "kernel: [1234.567] Out of memory: Kill process 12345 (postgres)"
            ],
            'disk_usage': "85%",
            'services_failed': []
        }
        
        return changes
    
    def format_changes_for_analysis(self, changes: Dict[str, Any]) -> str:
        """Format changes into analysis prompt"""
        prompt = f"""
Analyze these changes from host {changes['hostname']}:

**Command History (Last 24h):**
{chr(10).join(changes.get('command_history', []))}

**Package Changes:**
{chr(10).join(changes.get('apt_changes', []))}

**Docker Configuration:** {changes.get('docker_integrity', 'unknown')}

**System Errors:**
{chr(10).join(changes.get('system_errors', []))}

**Disk Usage:** {changes.get('disk_usage', 'unknown')}

**Failed Services:** {', '.join(changes.get('services_failed', [])) or 'None'}

Based on this host monitoring data, provide a security and operational assessment.

Focus on:
1. Security concerns (unauthorized access, suspicious commands)
2. Configuration drift (unexpected changes)
3. System health issues
4. Anything requiring immediate action

Respond in JSON format with:
{{
  "severity": "low|medium|high|critical",
  "summary": "One-line summary",
  "concerns": [
    {{"type": "security|config|operational", "issue": "description"}}
  ],
  "recommendations": ["actionable items"],
  "requires_action": true/false
}}
"""
        return prompt
    
    def analyze_changes_with_llm(self, hostname: str, changes: Dict[str, Any]) -> Dict[str, Any]:
        """Analyze changes using Claude"""
        logger.info(f"Analyzing changes from {hostname} with LLM...")
        
        prompt = self.format_changes_for_analysis(changes)
        
        try:
            response = self.llm.messages.create(
                model="claude-3-5-sonnet-20241022",
                max_tokens=1024,
                messages=[
                    {
                        "role": "user",
                        "content": prompt
                    }
                ]
            )
            
            response_text = response.content[0].text
            
            # Try to parse as JSON
            try:
                # Extract JSON from response (in case LLM adds markdown)
                import re
                json_match = re.search(r'\{.*\}', response_text, re.DOTALL)
                if json_match:
                    analysis = json.loads(json_match.group())
                else:
                    analysis = json.loads(response_text)
            except json.JSONDecodeError:
                # If not valid JSON, create structure from text
                analysis = {
                    "severity": "medium",
                    "summary": response_text[:100],
                    "concerns": [{"type": "analysis", "issue": response_text}],
                    "recommendations": ["Review LLM response manually"],
                    "requires_action": False
                }
            
            return analysis
        
        except Exception as e:
            logger.error(f"Error analyzing changes: {e}")
            return {
                "severity": "error",
                "summary": f"Analysis failed: {str(e)}",
                "concerns": [],
                "recommendations": ["Check LLM configuration and API key"],
                "requires_action": False
            }
    
    def write_audit_log(self, hostname: str, changes: Dict[str, Any], 
                       analysis: Dict[str, Any]):
        """Write analysis result to audit log"""
        self.audit_log.parent.mkdir(parents=True, exist_ok=True)
        
        timestamp = datetime.utcnow().isoformat()
        
        log_entry = f"""
{'='*80}
AUDIT ENTRY: {timestamp}
{'='*80}
Hostname: {hostname}
Severity: {analysis.get('severity', 'unknown')}
Summary: {analysis.get('summary', 'No summary')}

Concerns:
{chr(10).join([f"  - [{c.get('type', 'unknown')}] {c.get('issue', 'N/A')}" 
               for c in analysis.get('concerns', [])])}

Recommendations:
{chr(10).join([f"  - {r}" for r in analysis.get('recommendations', [])])}

Requires Immediate Action: {analysis.get('requires_action', False)}

Full Analysis:
{json.dumps(analysis, indent=2)}

{'='*80}
"""
        
        with open(self.audit_log, 'a') as f:
            f.write(log_entry)
        
        logger.info(f"Wrote audit entry for {hostname}")
    
    async def analyze_host(self, hostname: str):
        """Analyze a single host"""
        if hostname not in self.hosts:
            logger.error(f"Host not found: {hostname}")
            return
        
        # Collect changes
        changes = self.simulate_collect_host_changes(hostname)
        
        # Analyze with LLM
        analysis = self.analyze_changes_with_llm(hostname, changes)
        
        # Write to audit log
        self.write_audit_log(hostname, changes, analysis)
        
        # Print summary
        self.print_analysis(hostname, analysis)
    
    def print_analysis(self, hostname: str, analysis: Dict[str, Any]):
        """Print analysis summary to console"""
        severity = analysis.get('severity', 'unknown').upper()
        
        # Color code severity
        colors = {
            'CRITICAL': '\033[91m',  # Red
            'HIGH': '\033[93m',      # Yellow
            'MEDIUM': '\033[94m',    # Blue
            'LOW': '\033[92m',       # Green
            'ERROR': '\033[91m'      # Red
        }
        
        color = colors.get(severity, '')
        reset = '\033[0m'
        
        print(f"\n{color}{'='*60}{reset}")
        print(f"{color}ANALYSIS RESULT: {hostname}{reset}")
        print(f"{color}{'='*60}{reset}")
        print(f"Severity: {color}{severity}{reset}")
        print(f"Summary:  {analysis.get('summary', 'N/A')}")
        print(f"\nConcerns:")
        for concern in analysis.get('concerns', []):
            print(f"  - [{concern.get('type', 'unknown')}] {concern.get('issue', 'N/A')}")
        print(f"\nRecommendations:")
        for rec in analysis.get('recommendations', []):
            print(f"  - {rec}")
        if analysis.get('requires_action'):
            print(f"\n{color}⚠️  IMMEDIATE ACTION REQUIRED{reset}")
        print(f"{color}{'='*60}{reset}\n")
    
    async def analyze_all_hosts(self):
        """Analyze all configured hosts"""
        logger.info(f"Starting analysis of {len(self.hosts)} hosts...")
        
        for hostname in self.hosts:
            await self.analyze_host(hostname)
        
        logger.info("Analysis complete")
    
    def show_audit_history(self, lines: int = 50):
        """Show recent audit history"""
        if not self.audit_log.exists():
            print("No audit log found")
            return
        
        with open(self.audit_log) as f:
            content = f.read()
        
        # Show last N lines
        lines_list = content.split('\n')
        recent = '\n'.join(lines_list[-lines:])
        print(recent)
    
    def show_report(self, since_hours: int = 24):
        """Show analysis report for recent period"""
        if not self.audit_log.exists():
            print("No audit log found")
            return
        
        print(f"\nHost Monitoring Report (Last {since_hours} hours)")
        print("="*60)
        
        with open(self.audit_log) as f:
            content = f.read()
        
        # Count severity levels
        high_count = content.count('Severity: high')
        critical_count = content.count('Severity: critical')
        medium_count = content.count('Severity: medium')
        low_count = content.count('Severity: low')
        
        print(f"Critical:  {critical_count}")
        print(f"High:      {high_count}")
        print(f"Medium:    {medium_count}")
        print(f"Low:       {low_count}")
        print("="*60)
        
        # Show entries requiring action
        if 'Requires Immediate Action: True' in content:
            print("\n⚠️  FINDINGS REQUIRING IMMEDIATE ACTION:\n")
            entries = content.split('AUDIT ENTRY:')[1:]
            for entry in entries:
                if 'Requires Immediate Action: True' in entry:
                    lines = entry.split('\n')
                    hostname = [l for l in lines if l.startswith('Hostname:')]
                    summary = [l for l in lines if l.startswith('Summary:')]
                    if hostname:
                        print(f"  {hostname[0]}")
                    if summary:
                        print(f"  {summary[0]}")
                    print()


async def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='MCP-Based Host Monitoring Application'
    )
    parser.add_argument('--config', default='config/monitoring.yaml',
                       help='Configuration file path')
    parser.add_argument('--analyze', help='Analyze specific host')
    parser.add_argument('--all', action='store_true',
                       help='Analyze all hosts')
    parser.add_argument('--history', action='store_true',
                       help='Show audit history')
    parser.add_argument('--report', action='store_true',
                       help='Show analysis report')
    parser.add_argument('--test', action='store_true',
                       help='Test configuration without analyzing')
    
    args = parser.parse_args()
    
    try:
        monitor = MCPHostMonitor(args.config)
        
        if args.test:
            print(f"✓ Configuration loaded successfully")
            print(f"✓ {len(monitor.hosts)} hosts configured")
            for hostname in monitor.hosts:
                print(f"  - {hostname}")
            return
        
        if args.history:
            monitor.show_audit_history()
        elif args.report:
            monitor.show_report()
        elif args.analyze:
            await monitor.analyze_host(args.analyze)
        elif args.all:
            await monitor.analyze_all_hosts()
        else:
            # Default: analyze all hosts
            await monitor.analyze_all_hosts()
    
    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)


if __name__ == '__main__':
    asyncio.run(main())
