"""
Site Report Generator for dthostmon
Last Updated: 11/15/2025 6:15:00 PM CDT

Generates site-wide Markdown reports showing:
- Critical items across all systems in the site
- Systems with recent changes (history, apt installs)
- Resource usage table for all hosts
- Configurable thresholds for health status
"""

from datetime import datetime
from typing import Dict, List, Any, Optional
import logging

logger = logging.getLogger(__name__)


class SiteReportGenerator:
    """Generate site-wide status reports in Markdown format"""
    
    def __init__(self, site_name: str, resource_thresholds: Dict[str, tuple] = None):
        """
        Initialize site report generator.
        
        Args:
            site_name: Site identifier (e.g., 's01-chicago')
            resource_thresholds: Resource usage thresholds (health, info, warning, critical)
        """
        self.site_name = site_name
        
        # Default thresholds if not provided
        self.resource_thresholds = resource_thresholds or {
            'health': (0, 30),
            'info': (31, 60),
            'warning': (61, 89),
            'critical': (90, 100)
        }
    
    def generate_report(
        self,
        host_data: List[Dict[str, Any]],
        site_summary: Optional[Dict[str, Any]] = None
    ) -> str:
        """
        Generate complete site report in Markdown.
        
        Args:
            host_data: List of host monitoring data dictionaries
            site_summary: Optional site-level summary information
        
        Returns:
            Markdown-formatted report string
        """
        logger.info(f"Generating site report for {self.site_name}")
        
        report_sections = []
        
        # Header
        report_sections.append(self._generate_header(len(host_data)))
        
        # Critical Items Section (always first if present)
        critical_items = self._extract_critical_items(host_data)
        if critical_items:
            report_sections.append(self._generate_critical_items_section(critical_items))
        
        # Site Overview
        report_sections.append(self._generate_site_overview_section(host_data))
        
        # Systems with Changes
        systems_with_changes = self._extract_systems_with_changes(host_data)
        if systems_with_changes:
            report_sections.append(self._generate_changes_section(systems_with_changes))
        
        # Resource Usage Table
        report_sections.append(self._generate_resource_table(host_data))
        
        # Storage Highlights
        storage_highlights = self._extract_storage_highlights(host_data)
        if storage_highlights:
            report_sections.append(self._generate_storage_highlights_section(storage_highlights))
        
        # Footer
        report_sections.append(self._generate_footer())
        
        return "\n\n".join(report_sections)
    
    def _generate_header(self, host_count: int) -> str:
        """
        Generate report header with metadata.
        
        Args:
            host_count: Number of hosts in site
        
        Returns:
            Markdown header string
        """
        now = datetime.utcnow()
        
        return f"""# Site Status Report: {self.site_name}

**Generated:** {now.strftime('%Y-%m-%d %H:%M:%S UTC')}  
**Total Hosts:** {host_count}  
**Report Type:** Site-Wide Overview

---
"""
    
    def _generate_critical_items_section(self, critical_items: List[Dict[str, Any]]) -> str:
        """
        Generate critical items section aggregated across all hosts.
        
        Args:
            critical_items: List of critical issue dictionaries
        
        Returns:
            Markdown section
        """
        section = ["## 🚨 CRITICAL ITEMS ACROSS SITE", ""]
        
        if not critical_items:
            section.append("*No critical issues detected across the site.*")
            return "\n".join(section)
        
        # Group by host
        items_by_host = {}
        for item in critical_items:
            host = item.get('host', 'Unknown')
            if host not in items_by_host:
                items_by_host[host] = []
            items_by_host[host].append(item)
        
        for host, items in sorted(items_by_host.items()):
            section.append(f"### Host: {host}")
            section.append("")
            
            for idx, item in enumerate(items, 1):
                section.append(f"{idx}. **{item.get('title', 'Unknown Issue')}** ({item.get('severity', 'CRITICAL')})")
                section.append(f"   - {item.get('description', 'No description.')}")
                if 'recommendation' in item:
                    section.append(f"   - *Action:* {item['recommendation']}")
                section.append("")
        
        return "\n".join(section)
    
    def _generate_site_overview_section(self, host_data: List[Dict[str, Any]]) -> str:
        """
        Generate site overview with aggregate statistics.
        
        Args:
            host_data: List of host monitoring data
        
        Returns:
            Markdown section
        """
        section = ["## 📊 Site Overview", ""]
        
        # Calculate aggregate stats
        total_hosts = len(host_data)
        healthy_hosts = 0
        warning_hosts = 0
        critical_hosts = 0
        
        avg_cpu = 0
        avg_memory = 0
        avg_disk = 0
        
        for host in host_data:
            metrics = host.get('metrics', {})
            
            # Count host health status
            cpu = metrics.get('cpu_percent', 0)
            memory = metrics.get('memory_percent', 0)
            disk = metrics.get('disk_percent', 0)
            
            avg_cpu += cpu
            avg_memory += memory
            avg_disk += disk
            
            # Determine worst status for this host
            max_usage = max(cpu, memory, disk)
            status = self._get_resource_status(max_usage)
            
            if status.lower() == 'critical':
                critical_hosts += 1
            elif status.lower() == 'warning':
                warning_hosts += 1
            else:
                healthy_hosts += 1
        
        if total_hosts > 0:
            avg_cpu /= total_hosts
            avg_memory /= total_hosts
            avg_disk /= total_hosts
        
        # Display stats
        section.append(f"**Total Hosts:** {total_hosts}")
        section.append(f"- ✅ Healthy: {healthy_hosts}")
        section.append(f"- ⚠️ Warning: {warning_hosts}")
        section.append(f"- 🚨 Critical: {critical_hosts}")
        section.append("")
        
        section.append("**Average Resource Usage:**")
        section.append(f"- CPU: {avg_cpu:.1f}%")
        section.append(f"- Memory: {avg_memory:.1f}%")
        section.append(f"- Disk: {avg_disk:.1f}%")
        
        return "\n".join(section)
    
    def _generate_changes_section(self, systems_with_changes: List[Dict[str, Any]]) -> str:
        """
        Generate section showing systems with recent changes.
        
        Args:
            systems_with_changes: List of systems with change data
        
        Returns:
            Markdown section
        """
        section = ["## 🔄 Systems with Recent Changes", ""]
        
        if not systems_with_changes:
            section.append("*No significant changes detected across the site.*")
            return "\n".join(section)
        
        for system in systems_with_changes[:10]:  # Top 10 systems
            host_name = system.get('host', 'Unknown')
            change_count = system.get('change_count', 0)
            change_types = system.get('change_types', [])
            
            section.append(f"### {host_name}")
            section.append(f"**Changes Detected:** {change_count}")
            section.append(f"**Types:** {', '.join(change_types)}")
            section.append("")
            
            # Show sample changes
            if 'recent_changes' in system:
                section.append("**Recent Activity:**")
                for change in system['recent_changes'][:3]:
                    section.append(f"- {change.get('description', 'Unknown change')}")
                section.append("")
        
        if len(systems_with_changes) > 10:
            section.append(f"*...and {len(systems_with_changes) - 10} more systems with changes*")
        
        return "\n".join(section)
    
    def _generate_resource_table(self, host_data: List[Dict[str, Any]]) -> str:
        """
        Generate resource usage table for all hosts.
        
        Args:
            host_data: List of host monitoring data
        
        Returns:
            Markdown section with table
        """
        section = ["## 💾 Host Resource Usage", ""]
        
        if not host_data:
            section.append("*No host data available.*")
            return "\n".join(section)
        
        # Table header
        section.append("| Host | CPU | Memory | Disk | Status |")
        section.append("|------|-----|--------|------|--------|")
        
        # Sort by worst resource usage (highest percentage)
        sorted_hosts = sorted(
            host_data,
            key=lambda h: max(
                h.get('metrics', {}).get('cpu_percent', 0),
                h.get('metrics', {}).get('memory_percent', 0),
                h.get('metrics', {}).get('disk_percent', 0)
            ),
            reverse=True
        )
        
        for host in sorted_hosts:
            host_name = host.get('host_name', 'Unknown')
            metrics = host.get('metrics', {})
            
            cpu = metrics.get('cpu_percent', 0)
            memory = metrics.get('memory_percent', 0)
            disk = metrics.get('disk_percent', 0)
            
            # Determine overall status
            max_usage = max(cpu, memory, disk)
            status = self._get_resource_status(max_usage)
            emoji = self._get_status_emoji(status)
            
            section.append(
                f"| {host_name} | {cpu:.1f}% | {memory:.1f}% | {disk:.1f}% | {emoji} {status} |"
            )
        
        return "\n".join(section)
    
    def _generate_storage_highlights_section(self, storage_highlights: List[Dict[str, Any]]) -> str:
        """
        Generate section highlighting systems near storage limits.
        
        Args:
            storage_highlights: List of systems with storage concerns
        
        Returns:
            Markdown section
        """
        section = ["## 💿 Storage Highlights", ""]
        
        if not storage_highlights:
            section.append("*All systems within acceptable storage limits.*")
            return "\n".join(section)
        
        section.append("**Systems Approaching Storage Limits:**")
        section.append("")
        
        for highlight in storage_highlights:
            host_name = highlight.get('host', 'Unknown')
            disk_usage = highlight.get('disk_percent', 0)
            free_gb = highlight.get('disk_free_gb', 0)
            status = self._get_resource_status(disk_usage)
            emoji = self._get_status_emoji(status)
            
            section.append(
                f"- {emoji} **{host_name}**: {disk_usage:.1f}% used ({free_gb:.1f} GB free) - {status}"
            )
        
        return "\n".join(section)
    
    def _generate_footer(self) -> str:
        """Generate report footer"""
        return f"""---

*Site report generated by dthostmon at {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}*
"""
    
    def _extract_critical_items(self, host_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Extract all critical issues from all hosts.
        
        Args:
            host_data: List of host monitoring data
        
        Returns:
            List of critical item dictionaries
        """
        critical = []
        
        for host in host_data:
            host_name = host.get('host_name', 'Unknown')
            
            # Check metrics for critical thresholds
            metrics = host.get('metrics', {})
            for metric_name in ['cpu_percent', 'memory_percent', 'disk_percent']:
                if metric_name in metrics:
                    value = metrics[metric_name]
                    if value >= self.resource_thresholds['critical'][0]:
                        critical.append({
                            'host': host_name,
                            'title': f"High {metric_name.replace('_', ' ').title()}",
                            'severity': 'CRITICAL',
                            'description': f"{metric_name.replace('_', ' ').title()} at {value:.1f}%",
                            'recommendation': f"Investigate {host_name} immediately"
                        })
            
            # Add host-reported critical issues
            if 'critical_issues' in host:
                for issue in host['critical_issues']:
                    critical.append({
                        'host': host_name,
                        **issue
                    })
        
        return critical
    
    def _extract_systems_with_changes(self, host_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Extract systems that have recent changes.
        
        Args:
            host_data: List of host monitoring data
        
        Returns:
            List of system change summaries
        """
        systems_with_changes = []
        
        for host in host_data:
            changes = host.get('detected_changes', [])
            
            if changes:
                # Categorize changes
                change_types = set()
                for change in changes:
                    category = change.get('category', 'Other')
                    change_types.add(category)
                
                systems_with_changes.append({
                    'host': host.get('host_name', 'Unknown'),
                    'change_count': len(changes),
                    'change_types': sorted(list(change_types)),
                    'recent_changes': changes[:5]  # Top 5 changes
                })
        
        # Sort by change count (most changes first)
        return sorted(systems_with_changes, key=lambda s: s['change_count'], reverse=True)
    
    def _extract_storage_highlights(self, host_data: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Extract systems with storage concerns.
        
        Args:
            host_data: List of host monitoring data
        
        Returns:
            List of storage highlight dictionaries
        """
        highlights = []
        
        for host in host_data:
            metrics = host.get('metrics', {})
            disk_usage = metrics.get('disk_percent', 0)
            
            # Only highlight if in warning or critical range
            if disk_usage >= self.resource_thresholds['warning'][0]:
                highlights.append({
                    'host': host.get('host_name', 'Unknown'),
                    'disk_percent': disk_usage,
                    'disk_free_gb': metrics.get('disk_free_gb', 0)
                })
        
        # Sort by disk usage (highest first)
        return sorted(highlights, key=lambda h: h['disk_percent'], reverse=True)
    
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
