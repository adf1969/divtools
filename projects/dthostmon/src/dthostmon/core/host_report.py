"""
Host Report Generator for dthostmon
Last Updated: 11/15/2025 6:00:00 PM CDT

Generates comprehensive Markdown reports for individual hosts showing:
- Critical issues (highlighted)
- System changes (history logs, apt logs, filesystem)
- Log analysis (syslog, /var/log/*, docker container logs)
- System health (CPU, Memory, Disk metrics)
- Non-critical items (documented lower in report)
"""

from datetime import datetime
from typing import Dict, List, Any, Optional
import logging
import re

logger = logging.getLogger(__name__)


class HostReportGenerator:
    """Generate comprehensive host status reports in Markdown format"""
    
    def __init__(self, host_config: Dict[str, Any], resource_thresholds: Dict[str, tuple] = None):
        """
        Initialize host report generator.
        
        Args:
            host_config: Host configuration dictionary
            resource_thresholds: Resource usage thresholds (health, info, warning, critical)
        """
        self.host_config = host_config
        self.host_name = host_config.get('name', 'Unknown')
        self.site = host_config.get('site', 'N/A')
        
        # Default thresholds if not provided
        self.resource_thresholds = resource_thresholds or {
            'health': (0, 30),
            'info': (31, 60),
            'warning': (61, 89),
            'critical': (90, 100)
        }
    
    def generate_report(
        self,
        monitoring_data: Dict[str, Any],
        ai_analysis: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Generate complete host report in Markdown.
        
        Args:
            monitoring_data: Collected monitoring data (logs, metrics, changes)
            ai_analysis: Optional AI analysis results
        
        Returns:
            Markdown-formatted report string
        """
        logger.info(f"Generating host report for {self.host_name}")
        
        report_sections = []
        
        # Header
        report_sections.append(self._generate_header())
        
        # Critical Issues Section (always first if present)
        critical_issues = self._extract_critical_issues(monitoring_data, ai_analysis)
        if critical_issues:
            report_sections.append(self._generate_critical_issues_section(critical_issues))
        
        # System Health Summary
        report_sections.append(self._generate_system_health_section(monitoring_data))
        
        # System Changes
        report_sections.append(self._generate_system_changes_section(monitoring_data))
        
        # Log Analysis
        report_sections.append(self._generate_log_analysis_section(monitoring_data))
        
        # Docker Container Logs (if applicable)
        if 'docker_logs' in monitoring_data and monitoring_data['docker_logs']:
            report_sections.append(self._generate_docker_logs_section(monitoring_data))
        
        # Non-Critical Items
        non_critical = self._extract_non_critical_items(monitoring_data, ai_analysis)
        if non_critical:
            report_sections.append(self._generate_non_critical_section(non_critical))
        
        # AI Analysis Summary (if available)
        if ai_analysis:
            report_sections.append(self._generate_ai_analysis_section(ai_analysis))
        
        # Footer
        report_sections.append(self._generate_footer())
        
        return "\n\n".join(report_sections)
    
    def _generate_header(self) -> str:
        """Generate report header with metadata"""
        now = datetime.utcnow()
        
        return f"""# Host Status Report: {self.host_name}

**Generated:** {now.strftime('%Y-%m-%d %H:%M:%S UTC')}  
**Site:** {self.site}  
**Hostname:** {self.host_config.get('hostname', 'N/A')}  
**Tags:** {', '.join(self.host_config.get('tags', []))}

---
"""
    
    def _generate_critical_issues_section(self, critical_issues: List[Dict[str, Any]]) -> str:
        """
        Generate critical issues section with highlighted items.
        
        Args:
            critical_issues: List of critical issue dictionaries
        
        Returns:
            Markdown section
        """
        section = ["## 🚨 CRITICAL ISSUES", ""]
        
        if not critical_issues:
            section.append("*No critical issues detected.*")
            return "\n".join(section)
        
        for idx, issue in enumerate(critical_issues, 1):
            section.append(f"### {idx}. {issue.get('title', 'Unknown Issue')}")
            section.append(f"**Severity:** {issue.get('severity', 'CRITICAL')}")
            section.append(f"**Category:** {issue.get('category', 'General')}")
            section.append("")
            section.append(issue.get('description', 'No description available.'))
            section.append("")
            
            if 'recommendation' in issue:
                section.append(f"**Recommended Action:** {issue['recommendation']}")
                section.append("")
        
        return "\n".join(section)
    
    def _generate_system_health_section(self, monitoring_data: Dict[str, Any]) -> str:
        """
        Generate system health section with metrics.
        
        Args:
            monitoring_data: Monitoring data containing metrics
        
        Returns:
            Markdown section
        """
        section = ["## 📊 System Health Overview", ""]
        
        metrics = monitoring_data.get('metrics', {})
        
        # CPU
        cpu_usage = metrics.get('cpu_percent', 0)
        cpu_status = self._get_resource_status(cpu_usage)
        cpu_emoji = self._get_status_emoji(cpu_status)
        section.append(f"**CPU Usage:** {cpu_emoji} {cpu_usage:.1f}% ({cpu_status})")
        
        # Memory
        memory_usage = metrics.get('memory_percent', 0)
        memory_status = self._get_resource_status(memory_usage)
        memory_emoji = self._get_status_emoji(memory_status)
        section.append(f"**Memory Usage:** {memory_emoji} {memory_usage:.1f}% ({memory_status})")
        
        # Disk
        disk_usage = metrics.get('disk_percent', 0)
        disk_status = self._get_resource_status(disk_usage)
        disk_emoji = self._get_status_emoji(disk_status)
        section.append(f"**Disk Usage:** {disk_emoji} {disk_usage:.1f}% ({disk_status})")
        
        section.append("")
        
        # Additional metrics table
        if metrics:
            section.append("### Detailed Metrics")
            section.append("")
            section.append("| Metric | Value |")
            section.append("|--------|-------|")
            
            if 'uptime_days' in metrics:
                section.append(f"| Uptime | {metrics['uptime_days']:.1f} days |")
            if 'load_average' in metrics:
                section.append(f"| Load Average (1/5/15min) | {metrics['load_average']} |")
            if 'disk_free_gb' in metrics:
                section.append(f"| Disk Free | {metrics['disk_free_gb']:.1f} GB |")
            if 'memory_free_gb' in metrics:
                section.append(f"| Memory Free | {metrics['memory_free_gb']:.1f} GB |")
        
        return "\n".join(section)
    
    def _generate_system_changes_section(self, monitoring_data: Dict[str, Any]) -> str:
        """
        Generate system changes section (history, apt, filesystem).
        
        Args:
            monitoring_data: Monitoring data
        
        Returns:
            Markdown section
        """
        section = ["## 🔄 System Changes", ""]
        
        changes = monitoring_data.get('detected_changes', [])
        
        if not changes:
            section.append("*No significant changes detected since last monitoring run.*")
            return "\n".join(section)
        
        # Group changes by category
        change_categories = {}
        for change in changes:
            category = change.get('category', 'Other')
            if category not in change_categories:
                change_categories[category] = []
            change_categories[category].append(change)
        
        # Display changes by category
        for category, category_changes in sorted(change_categories.items()):
            section.append(f"### {category}")
            section.append("")
            
            for change in category_changes[:10]:  # Limit to 10 per category
                section.append(f"- **{change.get('timestamp', 'N/A')}**: {change.get('description', 'Unknown change')}")
            
            if len(category_changes) > 10:
                section.append(f"- *...and {len(category_changes) - 10} more {category.lower()} changes*")
            
            section.append("")
        
        return "\n".join(section)
    
    def _generate_log_analysis_section(self, monitoring_data: Dict[str, Any]) -> str:
        """
        Generate log analysis section (syslog, /var/log/*).
        
        Args:
            monitoring_data: Monitoring data
        
        Returns:
            Markdown section
        """
        section = ["## 📝 Log File Analysis", ""]
        
        log_entries = monitoring_data.get('log_entries', [])
        
        if not log_entries:
            section.append("*No log entries retrieved.*")
            return "\n".join(section)
        
        # Group logs by file
        logs_by_file = {}
        for entry in log_entries:
            log_path = entry.get('log_file_path', 'Unknown')
            if log_path not in logs_by_file:
                logs_by_file[log_path] = []
            logs_by_file[log_path].append(entry)
        
        for log_path, entries in sorted(logs_by_file.items()):
            section.append(f"### {log_path}")
            section.append("")
            
            # Show highlights (errors, warnings)
            highlights = self._extract_log_highlights(entries)
            
            if highlights:
                section.append("**Highlights:**")
                for highlight in highlights[:5]:  # Top 5 highlights
                    section.append(f"- {highlight}")
                section.append("")
            
            # Summary stats
            total_lines = sum(e.get('line_count', 0) for e in entries)
            section.append(f"*Total lines: {total_lines}, Files analyzed: {len(entries)}*")
            section.append("")
        
        return "\n".join(section)
    
    def _generate_docker_logs_section(self, monitoring_data: Dict[str, Any]) -> str:
        """
        Generate Docker container logs section.
        
        Args:
            monitoring_data: Monitoring data
        
        Returns:
            Markdown section
        """
        section = ["## 🐳 Docker Container Logs", ""]
        
        docker_logs = monitoring_data.get('docker_logs', [])
        
        if not docker_logs:
            section.append("*No Docker containers found or logs not available.*")
            return "\n".join(section)
        
        for container in docker_logs:
            container_name = container.get('name', 'Unknown')
            status = container.get('status', 'Unknown')
            
            section.append(f"### {container_name}")
            section.append(f"**Status:** {status}")
            section.append("")
            
            # Show recent log highlights
            logs = container.get('logs', '')
            if logs:
                highlights = self._extract_log_highlights_from_text(logs)
                if highlights:
                    section.append("**Recent Activity:**")
                    for highlight in highlights[:5]:
                        section.append(f"- {highlight}")
                else:
                    section.append("*No significant activity in recent logs.*")
            else:
                section.append("*No logs available.*")
            
            section.append("")
        
        return "\n".join(section)
    
    def _generate_non_critical_section(self, non_critical_items: List[Dict[str, Any]]) -> str:
        """
        Generate non-critical items section.
        
        Args:
            non_critical_items: List of non-critical item dictionaries
        
        Returns:
            Markdown section
        """
        section = ["## ℹ️ Non-Critical Items", ""]
        
        if not non_critical_items:
            section.append("*No non-critical items to report.*")
            return "\n".join(section)
        
        for idx, item in enumerate(non_critical_items, 1):
            section.append(f"{idx}. **{item.get('title', 'Unknown')}**: {item.get('description', 'N/A')}")
        
        return "\n".join(section)
    
    def _generate_ai_analysis_section(self, ai_analysis: Dict[str, Any]) -> str:
        """
        Generate AI analysis summary section.
        
        Args:
            ai_analysis: AI analysis results
        
        Returns:
            Markdown section
        """
        section = ["## 🤖 AI Analysis Summary", ""]
        
        if 'summary' in ai_analysis:
            section.append(ai_analysis['summary'])
            section.append("")
        
        if 'health_score' in ai_analysis:
            score = ai_analysis['health_score']
            section.append(f"**Overall Health Score:** {score}/100")
            section.append("")
        
        if 'recommendations' in ai_analysis and ai_analysis['recommendations']:
            section.append("### Recommendations")
            for rec in ai_analysis['recommendations']:
                section.append(f"- {rec}")
        
        return "\n".join(section)
    
    def _generate_footer(self) -> str:
        """Generate report footer"""
        return f"""---

*Report generated by dthostmon at {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}*
"""
    
    def _extract_critical_issues(
        self,
        monitoring_data: Dict[str, Any],
        ai_analysis: Optional[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Extract critical issues from monitoring data and AI analysis.
        
        Args:
            monitoring_data: Monitoring data
            ai_analysis: AI analysis results
        
        Returns:
            List of critical issue dictionaries
        """
        critical = []
        
        # Check metrics for critical thresholds
        metrics = monitoring_data.get('metrics', {})
        for metric_name in ['cpu_percent', 'memory_percent', 'disk_percent']:
            if metric_name in metrics:
                value = metrics[metric_name]
                if value >= self.resource_thresholds['critical'][0]:
                    critical.append({
                        'title': f"High {metric_name.replace('_', ' ').title()}",
                        'severity': 'CRITICAL',
                        'category': 'Resource Usage',
                        'description': f"{metric_name.replace('_', ' ').title()} is at {value:.1f}%, exceeding critical threshold.",
                        'recommendation': f"Investigate and reduce {metric_name.split('_')[0]} usage immediately."
                    })
        
        # Add AI-detected critical issues
        if ai_analysis and 'anomalies' in ai_analysis:
            for anomaly in ai_analysis['anomalies']:
                if anomaly.get('severity', '').upper() == 'CRITICAL':
                    critical.append({
                        'title': anomaly.get('title', 'AI-Detected Anomaly'),
                        'severity': 'CRITICAL',
                        'category': anomaly.get('category', 'AI Analysis'),
                        'description': anomaly.get('description', 'No description.'),
                        'recommendation': anomaly.get('recommendation', 'Review and investigate.')
                    })
        
        return critical
    
    def _extract_non_critical_items(
        self,
        monitoring_data: Dict[str, Any],
        ai_analysis: Optional[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Extract non-critical items from monitoring data.
        
        Args:
            monitoring_data: Monitoring data
            ai_analysis: AI analysis results
        
        Returns:
            List of non-critical item dictionaries
        """
        non_critical = []
        
        # Add informational changes
        changes = monitoring_data.get('detected_changes', [])
        for change in changes:
            if change.get('severity', '').lower() in ['info', 'low']:
                non_critical.append({
                    'title': change.get('description', 'Change detected'),
                    'description': change.get('details', 'No additional details.')
                })
        
        # Add AI-detected non-critical items
        if ai_analysis and 'anomalies' in ai_analysis:
            for anomaly in ai_analysis['anomalies']:
                if anomaly.get('severity', '').upper() in ['INFO', 'LOW', 'MEDIUM']:
                    non_critical.append({
                        'title': anomaly.get('title', 'Informational Item'),
                        'description': anomaly.get('description', 'No description.')
                    })
        
        return non_critical[:20]  # Limit to 20 items
    
    def _get_resource_status(self, percentage: float) -> str:
        """
        Determine resource status based on thresholds.
        
        Args:
            percentage: Resource usage percentage (0-100)
        
        Returns:
            Status string (Health, Info, Warning, Critical)
        """
        for status, (low, high) in self.resource_thresholds.items():
            if low <= percentage <= high:
                return status.title()
        return 'Unknown'
    
    def _get_status_emoji(self, status: str) -> str:
        """
        Get emoji for status level.
        
        Args:
            status: Status string
        
        Returns:
            Emoji character
        """
        emoji_map = {
            'health': '✅',
            'info': 'ℹ️',
            'warning': '⚠️',
            'critical': '🚨'
        }
        return emoji_map.get(status.lower(), 'ℹ️')
    
    def _extract_log_highlights(self, log_entries: List[Dict[str, Any]]) -> List[str]:
        """
        Extract highlights (errors, warnings) from log entries.
        
        Args:
            log_entries: List of log entry dictionaries
        
        Returns:
            List of highlight strings
        """
        highlights = []
        
        for entry in log_entries:
            content = entry.get('content', '')
            lines = content.split('\n')
            
            for line in lines:
                # Look for error/warning patterns
                if re.search(r'\b(error|fail|critical|fatal)\b', line, re.IGNORECASE):
                    highlights.append(line.strip())
                elif re.search(r'\b(warn|warning)\b', line, re.IGNORECASE):
                    highlights.append(line.strip())
        
        return highlights[:10]  # Top 10 highlights
    
    def _extract_log_highlights_from_text(self, log_text: str) -> List[str]:
        """
        Extract highlights from raw log text.
        
        Args:
            log_text: Raw log text
        
        Returns:
            List of highlight strings
        """
        highlights = []
        lines = log_text.split('\n')
        
        for line in lines:
            if re.search(r'\b(error|fail|critical|fatal|warn|warning)\b', line, re.IGNORECASE):
                highlights.append(line.strip())
        
        return highlights[:10]
