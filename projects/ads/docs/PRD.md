# Product Requirements Document (PRD) - Active Directory Services Infrastructure

## Overview

**Project Name:** Active Directory Services (ADS) - Multi-Site Domain Management

**Version:** 1.0.0

**Date:** December 4, 2025

**Author:** DivTools Project Team

## Executive Summary

This project implements an open-source Active Directory Services infrastructure to replace Zentyal with a modern, scalable solution built on industry-standard components (Samba, Kerberos, LDAP, Bind9). The system manages multiple domains within a forest structure across geographically distributed sites, supporting Windows workstations, Ubuntu systems, printers, and IoT devices while providing centralized authentication and resource management.

## Goals and Objectives

### Primary Goals
- **Replace Zentyal:** Migrate from Zentyal to open-source Samba-based ADS infrastructure
- **Multi-Site Management:** Support multiple geographic locations with unified domain management
- **High Availability:** Deploy redundant domain controllers across sites with automatic failover
- **Enterprise Integration:** Support Windows workstations, GPOs, and standard Windows management tools

### Secondary Goals
- **Scalability:** Support domains from small offices to large enterprise deployments
- **Cost Efficiency:** Reduce licensing costs through open-source tools
- **Operational Excellence:** Simplify user management, authentication, and resource sharing
- **Future Kubernetes Ready:** Architecture supports migration to K3s for container-based deployments

## Target Audience

- System Administrators managing multi-site networks
- IT Operations teams implementing domain-based authentication
- Organizations migrating from Zentyal or other proprietary solutions
- Infrastructure teams supporting mixed Windows/Linux environments

## Functional Requirements

### Domains and Forest Structure

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-01 | 1 | Primary domain (avctn.lan) | Successfully manages users, groups, computers, and resources |
| FR-02 | 2 | Multi-domain forest (avak.lan, cvg.lan, avc.lan) | Domains can trust each other and share resources across forest |
| FR-03 | 1 | Forest-wide user authentication | Users can authenticate from any domain in forest |
| FR-04 | 2 | Cross-domain group policies | GPOs applied consistently across all domains |

### User and Group Management

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-05 | 1 | User creation and deletion | Users can be created via CLI tools, LDAP, or Web UI |
| FR-06 | 1 | Group management | Security groups and distribution groups created and managed |
| FR-07 | 1 | User authentication | Domain users authenticate via Kerberos |
| FR-08 | 2 | Delegated administration | Site administrators can manage their site without domain admin access |
| FR-09 | 2 | Web-based user management | Web UI for user provisioning and password resets |

### Resource Sharing and Access Control

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-10 | 1 | CIFS/SMB shares | File sharing via Samba for Windows and Linux clients |
| FR-11 | 1 | Printer sharing | Network printer management and access control |
| FR-12 | 1 | Access control lists (ACLs) | Granular permission management on shared resources |
| FR-13 | 2 | Roaming profiles | User profiles sync across domain-joined computers |

### DNS and Name Resolution

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-14 | 1 | Authoritative DNS (Bind9) | DNS serves domain SRV records for AD discovery |
| FR-15 | 1 | Dynamic DNS updates | Samba updates DNS records for domain controllers and clients |
| FR-16 | 1 | Multi-site DNS | Each site has primary and secondary DNS servers |
| FR-17 | 1 | DNS forwarders | Domains can resolve external DNS queries via forwarders |

### High Availability and Replication

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-18 | 1 | Multiple domain controllers | At least 2 DCs per domain for redundancy |
| FR-19 | 1 | Directory replication | LDAP directory synced across all DCs |
| FR-20 | 1 | SYSVOL replication | Group policies synced via SYSVOL across DCs |
| FR-21 | 1 | Health monitoring | DC health status visible via monitoring system |
| FR-22 | 2 | Automatic failover | Services automatically redirect to healthy DC on failure |

### Windows Integration

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-23 | 1 | Domain join | Windows workstations can join domain via standard Windows UI |
| FR-24 | 1 | Group Policy Objects (GPOs) | Windows clients receive and apply GPOs from domain |
| FR-25 | 1 | Active Directory Users and Computers | Standard Windows ADUC tool works with ADS domain |
| FR-26 | 1 | Windows DNS Manager | DNS can be managed from Windows client tools |

### Linux/Ubuntu Integration

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-27 | 1 | SSH key authentication | Domain users authenticate via SSH with Kerberos or key-based auth |
| FR-28 | 1 | LDAP queries | Ubuntu systems can query LDAP directory for user information |
| FR-29 | 1 | CIFS client support | Ubuntu workstations mount Samba shares for file access |
| FR-30 | 2 | SSSD (System Security Services Daemon) | Ubuntu systems auto-sync domain users for local authentication |

### Multi-Site Architecture

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-31 | 1 | Site isolation | Each site (10.X.0.0/20) can operate independently if WAN link fails |
| FR-32 | 1 | Inter-site replication | Directory changes replicate between sites with defined RTO/RPO |
| FR-33 | 1 | Site-specific DNS | Each site has primary DNS, fallback to secondary site DNS |
| FR-34 | 2 | Cross-site group memberships | Users in one site can be members of groups in another site |

### Management Interfaces

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-35 | 1 | CLI tools (samba-tool) | Domain and user management via command-line |
| FR-36 | 1 | LDAP CLI tools | ldapsearch, ldapadd, ldapmodify for directory operations |
| FR-37 | 1 | SSH remote administration | Remote administration via SSH and terminal access |
| FR-38 | 2 | Web UI dashboard | Web-based dashboard for domain and site management |
| FR-39 | 2 | Reporting interface | Audit logs and compliance reporting dashboard |

### Management Scripts and Automation

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-44 | 1 | FSMO role checker script | Display which FSMO roles are held by which DCs with status |
| FR-45 | 1 | Samba health check script | Verify all Samba services operational, check replication status |
| FR-46 | 1 | Log aggregation script | Centralized access to Samba logs across multiple DCs with filtering |
| FR-47 | 1 | Daily maintenance script | Automated daily checks: replication, DNS, disk space, connectivity |
| FR-48 | 1 | Backup and recovery script | Automated backup of Samba config and directory with LDIF exports |
| FR-49 | 1 | User management CLI wrapper | Quick access to common user operations (create, disable, reset password) |
| FR-50 | 2 | GPO backup script | Automated backup and versioning of Group Policy Objects |
| FR-51 | 2 | Domain join automation | Script to automate Windows/Linux client domain join |
| FR-52 | 2 | Replication monitoring | Monitor and alert on replication lag or failures |

### Container and Infrastructure

| Requirement ID | Phase | Description | Expected Behavior/Outcome |
|---|---|---|---|
| FR-40 | 1 | Docker Compose deployment | Services defined in docker-compose-ads.yml |
| FR-41 | 1 | Environment variables | Configuration externalized in .env files (Docker Compose V2) |
| FR-42 | 2 | Kubernetes ready | Architecture supports K3s deployment without major changes |
| FR-43 | 1 | Health checks | Container health checks verify DC and service status |

## Non-Functional Requirements

### Performance

| Requirement ID | NFR | Description | Target |
|---|---|---|---|
| NFR-01 | Performance | User authentication latency | < 500ms for local DC, < 2s for remote DC |
| NFR-02 | Performance | Directory sync latency | < 60s between DCs |
| NFR-03 | Performance | CIFS file access | > 50 Mbps LAN, > 10 Mbps WAN |
| NFR-04 | Scalability | Maximum users per domain | 10,000+ with proper DC sizing |
| NFR-05 | Scalability | Maximum groups | 5,000+ per domain |

### Availability

| Requirement ID | NFR | Description | Target |
|---|---|---|---|
| NFR-06 | Availability | Domain availability | 99.9% uptime (multi-DC) |
| NFR-07 | Availability | DC failover time | < 30 seconds automatic failover |
| NFR-08 | RTO | Domain recovery RTO | < 1 hour for full domain recovery |
| NFR-09 | RPO | Directory replication RPO | < 5 minutes between sites |

### Security

| Requirement ID | NFR | Description | Target |
|---|---|---|---|
| NFR-10 | Security | Authentication protocol | Kerberos (SHA-256 minimum) |
| NFR-11 | Security | LDAP transport | LDAPS (TLS 1.2+) |
| NFR-12 | Security | Password policy | Minimum 12 characters, complexity required |
| NFR-13 | Security | Password expiry | 90 days default |
| NFR-14 | Security | Account lockout | Lockout after 5 failed attempts |
| NFR-15 | Security | Audit logging | All authentication and group changes logged |

### Reliability

| Requirement ID | NFR | Description | Target |
|---|---|---|---|
| NFR-16 | Reliability | Directory consistency | Zero data loss during replication |
| NFR-17 | Reliability | Backup frequency | Daily backups of directory and configuration |
| NFR-18 | Reliability | Backup testing | Weekly restore testing |

## Technical Architecture

### Core Components

**Primary Services:**
- **Samba AD DC:** Active Directory Domain Controller (LDAP, Kerberos, SMB)
- **Bind9:** DNS authority server for SRV record hosting
- **PostgreSQL:** Optional backend for extended directory attributes
- **NTP:** Chronyd for time synchronization

**Optional Services:**
- **TrueNAS Scale:** Centralized file storage with SMB shares
- **Postgres:** Database for application data and extended directory
- **Prometheus/InfluxDB:** Metrics collection for domain monitoring
- **Web UI:** Future dashboard for administration and reporting

### Network Architecture

**Port Requirements:**
- 53/udp, 53/tcp - DNS
- 88/udp, 88/tcp - Kerberos
- 135/tcp - RPC Endpoint Mapper
- 139/tcp - NetBIOS (SMB)
- 389/tcp - LDAP
- 445/tcp - SMB (CIFS)
- 464/udp, 464/tcp - Kerberos Password Change
- 636/tcp - LDAPS
- 3268/tcp - LDAP Global Catalog
- 3269/tcp - LDAPS Global Catalog

**Network Isolation:**
- Domain controllers on site-specific network (10.X.0.0/20)
- WAN links between sites with optimized replication
- Firewalls configured to allow inter-site domain traffic

### Deployment Platform

- **Primary Deployment:** Docker and Docker Compose (Phase 1)
- **Future Deployment:** Kubernetes (K3s) for HA production (Phase 3+)
- **Configuration:** Externalized in docker-compose-ads.yml and .env files
- **Base Image:** Ubuntu 22.04 or Debian 12 with Samba 4.18+

### Storage and Persistence

**Volumes:**
- `/etc/samba/` - Domain configuration and state
- `/var/lib/samba/` - Directory database and Kerberos keys
- `/var/lib/samba/sysvol/` - GPO storage
- `/var/log/samba/` - Audit logs
- Configuration externalized for easy management

## Implementation Phases

### Phase 1: Foundation (Month 1-2)
- Single domain (avctn.lan) with 2 domain controllers
- Samba AD DC, Bind9 DNS, NTP
- Basic user and group management via CLI
- Docker Compose deployment on ads1-98
- Health monitoring via Prometheus
- Documentation and testing

### Phase 2: Multi-Site Readiness (Month 2-3)
- Multi-site replication configuration
- Site-specific DNS setup
- Delegated administration per site
- Windows domain join and GPO testing
- Ubuntu LDAP client integration
- CIFS share management

### Phase 3: Multi-Domain Forest (Month 3-4)
- Additional domains (avak.lan, cvg.lan, avc.lan)
- Forest trust relationships
- Cross-domain group memberships
- Consolidated reporting

### Phase 4: Web UI and Automation (Month 4-5)
- Web-based user management dashboard
- Group Policy Editor Web UI
- Automated user provisioning workflows
- Compliance reporting and audit trails

### Phase 5: Kubernetes Migration (Month 5-6)
- Kubernetes-ready architecture
- K3s deployment manifests
- StatefulSet for domain controllers
- High-availability production deployment

## Success Criteria

- Single domain successfully manages 100+ users, groups, and computers
- All users can authenticate via Kerberos
- Windows workstations can join domain and apply GPOs
- Linux systems can query LDAP and mount SMB shares
- Multi-site replication works with < 5 minute RPO
- Web UI provides user-friendly administration interface
- System maintains 99.9% availability with multiple DCs
- Documentation covers all operational procedures
- All security policies enforced and auditable

## Constraints and Assumptions

### Constraints
- Must use open-source tools (no proprietary licensing)
- Must integrate with existing divtools Docker/Sites architecture
- Must support both Windows and Linux clients
- Must be deployable in air-gapped networks

### Assumptions
- Proxmox 8.4+ available for virtualization
- Ubuntu 22.04+ or Debian 12+ as base OS
- Docker and Docker Compose installed on deployment host
- NTP synchronization available (< 5 min clock skew)
- WAN connectivity between sites with 100+ Kbps minimum bandwidth
