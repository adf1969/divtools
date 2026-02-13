# Visual Architecture Diagram

## How host_change_log.sh Orchestrates Monitoring

```
┌─────────────────────────────────────────────────────────────────────┐
│  host_change_log.sh (Setup & Orchestration)                        │
└─────────────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
        ▼                 ▼                 ▼
    ┌────────────┐  ┌──────────────┐  ┌─────────────┐
    │   setup    │  │   manifest   │  │   verify    │
    │  (runs     │  │ (generates   │  │  (checks    │
    │   once)    │  │  metadata)   │  │   config)   │
    └────────────┘  └──────────────┘  └─────────────┘
        │                 │                   │
        └─────────────────┼───────────────────┘
                          │
        ┌─────────────────┴─────────────────────────┐
        │                                           │
        ▼                                           ▼
    ┌───────────────────────┐         ┌────────────────────────────┐
    │  /opt/dtlogs/         │         │  monitoring_manifest.json  │
    │  (Monitoring Base)    │         │  (Template for n8n)        │
    │                       │         │                            │
    ├─ history/            │         │  {                         │
    │  ├─ root.bash_      │         │    "bash_history": [...],  │
    │  │  history.latest  │         │    "apt_packages": [...],  │
    │  ├─ divix.bash_     │         │    "docker_configs": [...],│
    │  │  history.latest  │         │    "system_logs": [...]    │
    │  └─ drupal.bash_    │         │  }                         │
    │     history.latest  │         │                            │
    │                     │         └────────────────────────────┘
    ├─ logs/ (symlinks)   │
    │  ├─ apt-history.log ────→ /var/log/apt/history.log
    │  ├─ dpkg.log ────────────→ /var/log/dpkg.log
    │  ├─ syslog ──────────────→ /var/log/syslog
    │  └─ auth.log ────────────→ /var/log/auth.log
    │                     │
    ├─ checksums/        │
    │  └─ docker_configs  │
    │     .sha256         │
    │                     │
    ├─ apt/ (EMPTY)       │
    ├─ docker/ (EMPTY)    │
    └─ bin/               │
       └─ capture_tty_    │
          history.sh      │
```

---

## Data Flow: From Real Logs to Monitoring

```
BASH COMMAND EXECUTION
        │
        ▼
        shell writes to ~/.bash_history
        │
        ▼
        PROMPT_COMMAND trigger
        │
        ▼
        /opt/dtlogs/history/[user].bash_history.[timestamp]
        │
        ▼
        /opt/dtlogs/history/[user].bash_history.latest (symlink)
        │
        ▼
        monitoring_manifest.json says "watch this file"
        │
        ▼
        n8n checks file daily → detects new commands


PACKAGE INSTALLATION
        │
        ▼
        apt install package
        │
        ▼
        /var/log/apt/history.log (updated by APT)
        │
        ▼
        /opt/dtlogs/logs/apt-history.log (symlink)
        │
        ▼
        monitoring_manifest.json says "watch this file"
        │
        ▼
        n8n checks file daily → detects new installs


DOCKER CONFIGURATION CHANGE
        │
        ▼
        admin edits /home/divix/divtools/docker/docker-compose-*.yml
        │
        ▼
        Run: ./host_change_log.sh manifest
        │
        ▼
        calculate_docker_checksums() runs
        │
        ▼
        New SHA256 written to /opt/dtlogs/checksums/docker_configs.sha256
        │
        ▼
        Compare checksums: old vs new
        │
        ▼
        If different → docker-compose files changed!
```

---

## Single Manifest Design (Not Dual-Manifest)

```
BASELINE (First Run)
┌─────────────────────────────────────────┐
│ monitoring_manifest.json                │
│ timestamp: 2025-11-11T20:25:09Z         │
│ {                                       │
│   "bash_history": [                     │
│     ".../root.bash_history.latest",     │
│     ".../divix.bash_history.latest"     │
│   ],                                    │
│   "docker_configs": {                   │
│     "checksum_file": "...",             │
│     "checksums": {                      │
│       "docker-compose-core.yml": "a1b2" │
│     }                                   │
│   }                                     │
│ }                                       │
└─────────────────────────────────────────┘
              │
              │ [SYSTEM RUNS FOR 1 WEEK]
              │ [THINGS GET MODIFIED]
              │
              ▼
SECOND RUN (No Comparison)
┌─────────────────────────────────────────┐
│ monitoring_manifest.json (OVERWRITES)   │
│ timestamp: 2025-11-18T10:30:15Z         │  ← Different timestamp
│ {                                       │
│   "bash_history": [                     │
│     ".../root.bash_history.latest",     │  ← Still same files
│     ".../divix.bash_history.latest"     │  ← (but with new data)
│   ],                                    │
│   "docker_configs": {                   │
│     "checksum_file": "...",             │
│     "checksums": {                      │
│       "docker-compose-core.yml": "c3d4" │  ← Different! (file changed)
│     }                                   │
│   }                                     │
│ }                                       │
└─────────────────────────────────────────┘

EXTERNAL TOOL (n8n) DETECTS CHANGE
Compare: "a1b2" vs "c3d4" → ALERT! Docker config changed!
```

---

## Actual vs Empty Directories

```
ACTUAL CONTENT (Files being monitored):

/opt/dtlogs/history/
├── root.bash_history.20251111-201942          ← Real file with commands
├── root.bash_history.latest                   ← Symlink to above
├── divix.bash_history.20251111-201942         ← Real file with commands
├── divix.bash_history.latest                  ← Symlink to above
└── drupal.bash_history.20251111-201942        ← Real file with commands
    └── drupal.bash_history.latest             ← Symlink to above

/opt/dtlogs/logs/
├── apt-history.log → /var/log/apt/history.log          ← Symlink
├── dpkg.log → /var/log/dpkg.log                        ← Symlink
├── syslog → /var/log/syslog                            ← Symlink
└── auth.log → /var/log/auth.log                        ← Symlink

/opt/dtlogs/checksums/
└── docker_configs.sha256
    a1b2c3d4e5f6... docker-compose-core.yml
    f6e5d4c3b2a1... docker-compose-frigate.yml
    etc.

EMPTY (RESERVED FOR FUTURE):

/opt/dtlogs/apt/                    ← Could store apt snapshots
                                    ← Example: packages_20251111_201942.txt

/opt/dtlogs/docker/                 ← Could store docker-compose snapshots
                                    ← Example: 20251111_201942/
                                    │   ├── docker-compose-core.yml
                                    │   ├── docker-compose-frigate.yml
                                    │   └── docker-compose-monitor.yml
```

---

## What Changes Between Runs

```
RUN 1 (Nov 11, 20:25)
┌─────────────────────────────────────┐
│ monitoring_manifest.json (11 KB)    │
│ timestamp: 2025-11-11T20:25:09Z     │
│ docker checksums: 30KB              │
│ bash history files: 100KB total     │
│ Total on disk: ~200KB               │
└─────────────────────────────────────┘

[USER RUNS COMMANDS, INSTALLS PACKAGES, EDITS CONFIGS]

RUN 2 (Nov 12, 10:30)
┌─────────────────────────────────────┐
│ monitoring_manifest.json (11 KB)    │  ← Same structure
│ timestamp: 2025-11-12T10:30:15Z     │  ← Different timestamp ✓
│ docker checksums: 31KB              │  ← Recalculated ✓
│ bash history files: 150KB total     │  ← Larger (new commands) ✓
│ Total on disk: ~250KB               │  ← More data accumulated
└─────────────────────────────────────┘

WHAT ACTUALLY CHANGED:
✓ Manifest timestamp (metadata)
✓ Docker checksums (if configs changed)
✓ Bash history file sizes (growing with new commands)
✗ Manifest structure (same JSON keys)
✗ File paths listed (same locations)
```

---

## Change Detection Workflow

```
USER ACTION              IMMEDIATE LOG              MANIFEST ROLE
────────────────────────────────────────────────────────────────

User types command       → /opt/dtlogs/history/    monitoring_manifest.json
                           [user].bash_history     says: check this file
                           .latest                 
                           (updated real-time)     External tool
                                                   (n8n) runs:
                                                   - Compare timestamps
                                                   - Read new lines


Admin edits              → File on disk modified    monitoring_manifest.json
docker-compose.yml       → Changes immediately     provides:
                                                   - Baseline checksum
                                                   - Path to watch

                         Run: manifest command     External tool
                         → docker checksums        (n8n) runs:
                           recalculated            - Compute new SHA256
                         → manifest updated        - Compare to baseline
                           (timestamp changed)     - ALERT if different


Package installed        → /var/log/apt/           monitoring_manifest.json
(apt install foo)          history.log             says: check this file
                           (updated by APT)        
                                                   External tool
                                                   (n8n) runs:
                                                   - Check file modification
                                                   - Read new entries
                                                   - Detect install


System event             → /var/log/auth.log       monitoring_manifest.json
(failed login)           (updated by syslog)       says: check this file
                                                   
                                                   External tool
                                                   (n8n) runs:
                                                   - Grep for failures
                                                   - ALERT on suspicion
```

---

## Summary: Script vs External Tool

```
╔════════════════════════════════════════════════════════╗
║  host_change_log.sh                                   ║
║  ─────────────────────                                ║
║  ✓ Sets up directories                               ║
║  ✓ Configures bash history capture                   ║
║  ✓ Creates symlinks to logs                          ║
║  ✓ Calculates checksums                              ║
║  ✓ Generates manifest (template)                     ║
║  ✗ Does NOT detect changes                           ║
║  ✗ Does NOT compare files                            ║
║  ✗ Does NOT alert on differences                     ║
╚════════════════════════════════════════════════════════╝
                         ↓
╔════════════════════════════════════════════════════════╗
║  n8n (or similar external monitoring tool)           ║
║  ─────────────────────────────────────────            ║
║  ✓ Reads manifest to find files                      ║
║  ✓ Monitors files on a schedule (daily)              ║
║  ✓ Compares timestamps                               ║
║  ✓ Computes checksums                                ║
║  ✓ Detects changes                                   ║
║  ✓ ALERTS you to changes                             ║
║  ✗ Doesn't set up anything                           ║
║  ✗ Doesn't configure bash                            ║
║  ✗ Doesn't maintain logs                             ║
╚════════════════════════════════════════════════════════╝
```

These are **complementary**, not redundant.

