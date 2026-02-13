# Active Directory Services (ADS) - Multi-Site Domain Management

## Project Overview

This project implements an open-source Active Directory Services infrastructure using Samba and related tools to replace Zentyal. The goal is to create a robust, scalable domain management system that supports multiple sites and domains within a forest structure.

### Motivation

Zentyal, while useful, has significant limitations:

- **DNS Resolution Issues:** Inconsistent DNS handling and unauthorized modifications to `resolv.conf`
- **User Management:** Poor interface and limited functionality
- **CIFS Shares:** Inadequate sharing capabilities and management
- **UI/UX:** Clunky and unintuitive interface

This project aims to build a superior alternative using **industry-standard open-source tools** (Samba, Kerberos, LDAP, Bind9) that are well-documented, reliable, and widely adopted.

## Project Scope

### Current Domain Structure

- **Primary Domain:** avctn.lan (currently managed by Zentyal)
- **Additional Domains (Future):** avak.lan, cvg.lan, avc.lan (as additional forest domains)

### Infrastructure Foundation

- **Hypervisor:** Proxmox Server 8.4.x
- **Initial Test Platform:** ads1-98 (Docker VM for testing Samba migration)
- **Divtools Integration:** Leverages existing Docker/Sites architecture

### Multi-Site Architecture

Each site is defined by:

| Component | Format | Example |
|-----------|--------|---------|
| Site Number | 1-254 | 1 |
| Site Network | 10.${SITE_NUM}.0.0/20 | 10.1.0.0/20 |
| Site Name | s${SITE_NUM}-${SITE_DESC} | s01-7692nw |
| Host Path | $DIVTOOLS/docker/sites/${SITE_NAME}/${HOSTNAME}/ | docker/sites/s01-7692nw/gpu1-75/ |
| Services | ${SITE_HOST}/${APP}/ | frigate, samba, dns, etc. |

#### Managed Assets Per Site

- **Workstations:** Windows systems and Ubuntu Desktop systems
- **Network Infrastructure:** Omada TP-Link Access Points, Switches, and Routers
- **IoT & Services:** Home Assistant, Frigate, and other specialized devices
- **Storage:** TrueNAS Scale instances for centralized file storage
- **Orchestration:** Kubernetes (K3s) for distributed services and microservices
- **Databases:** PostgreSQL servers for application data storage

## Core Services & Capabilities

### Required Services

- **Samba (SMB/CIFS):** File and printer sharing, domain services
- **Kerberos:** Authentication protocol for domain members
- **LDAP:** Centralized directory service for user and group management
- **Bind9:** DNS authority for domain name resolution
- **NTP:** Time synchronization (critical for Kerberos)
- **High Availability:** Multiple Domain Controllers with replication and failover

### Planned Deployment Architecture

- **Container Platform:** Docker and Docker Compose for initial deployment
- **Orchestration:** Kubernetes (K3s) for future high-availability production deployments
- **Configuration:** Docker Compose V2 with environment variable management
- **Data Sync:** Multi-site replication using Samba SYSVOL synchronization

## Management Interfaces

### Windows Management

- **Active Directory Users and Computers (ADUaC):** Standard Windows domain management
- **DNS Manager:** Windows DNS client tools
- **Group Policy Editor (gpedit.msc):** For policy management via Windows workstations

### Linux/Ubuntu Management

- **SSH & Terminal:** Command-line administration of domain controllers
- **Web UI (Planned):** Future web dashboard for domain and site management
- **LDAP CLI Tools:** ldapsearch, ldapadd, ldapmodify for directory operations
- **Samba Tools:** samba-tool CLI for domain and user management

## Project Structure

```
projects/ads/
├── README.md                              # This file - Project overview
├── docs/
│   ├── PRD.md                            # Product Requirements Document
│   ├── PROJECT-HISTORY.md                # Project history and decisions
│   ├── DEPLOYMENT-GUIDE.md               # Docker Compose deployment
│   ├── SAMBA-CONFIGURATION.md            # Samba setup and best practices
│   ├── DNS-SETUP.md                      # Bind9 DNS configuration
│   ├── USER-MANAGEMENT.md                # LDAP/Samba user administration
│   ├── MULTI-SITE-REPLICATION.md         # Domain replication across sites
│   └── WINDOWS-INTEGRATION.md            # Windows client and tool integration
├── docker-compose-ads.yml                # Main ADS services compose file
├── scripts/
│   ├── init-domain.sh                    # Initialize new domain
│   ├── add-site.sh                       # Add new site to forest
│   ├── manage-users.sh                   # User and group management wrapper
│   └── health-check.sh                   # Domain health verification
└── tests/
    ├── domain-connectivity.sh            # Verify domain join and replication
    ├── dns-resolution.sh                 # Validate DNS functionality
    └── user-auth.sh                      # Test user authentication
```

## Best Practices

### Security

- **Kerberos Authentication:** Use strong Kerberos tickets for all service authentication
- **LDAP Security:** Implement LDAPS (LDAP over SSL/TLS) for encrypted communication
- **Group Policy:** Define and enforce GPOs for Windows client security policies
- **Password Policy:** Enforce strong password requirements at directory level
- **Access Control:** Implement ACLs based on site membership and organizational units

### High Availability

- **Multiple DCs:** Deploy at least 2 domain controllers per domain for redundancy
- **Replication:** Configure Samba replication (SYSVOL sync) across all DCs
- **Load Balancing:** Distribute authentication load across multiple DCs
- **Monitoring:** Implement health checks for DC availability and replication status
- **Backup/Recovery:** Regular backups of LDAP directory and Samba state

### Network Design

- **DNS Integration:** Ensure Bind9 serves SRV records for Kerberos and LDAP discovery
- **Firewall Rules:** Properly isolate domain traffic (ports 389, 636, 3268, 3269, 88, 464)
- **NTP Synchronization:** Keep system clocks within 5 minutes for Kerberos functionality
- **Site-specific DNS:** Each site should have primary and secondary DNS servers

### Operational Procedures

- **Monitoring:** Integrate with Prometheus and InfluxDB for metrics collection
- **Alerting:** Configure alerts for replication failures, login failures, and quota violations
- **Disaster Recovery:** Document RTO/RPO for domain recovery scenarios
- **Testing:** Regularly test failover and recovery procedures

## Installation & Configuration

For detailed implementation instructions, see:

- **Docker Deployment:** See `docs/DEPLOYMENT-GUIDE.md`
- **Samba Setup:** See `docs/SAMBA-CONFIGURATION.md`
- **User Management:** See `docs/USER-MANAGEMENT.md`
- **Multi-Site Configuration:** See `docs/MULTI-SITE-REPLICATION.md`

## Development Guidelines

As with all divtools projects:

- **Documentation:** Goes in `docs/` subfolder with clear filenames for each topic
- **Scripts:** Can be placed in `scripts/` folder at project root or in `$DIVTOOLS/scripts/`
- **Tests:** Go in `tests/` subfolder below the script location (e.g., `scripts/tests/`)
- **Testing Framework:** Python tests use pytest; shell scripts have unit test wrappers
- **Configuration:** Environment variables in `.env` files; committed templates use `.env.example`
