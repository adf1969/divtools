# TrueNAS Usage Correction - System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                        DEPLOYMENT PHASE                              │
└─────────────────────────────────────────────────────────────────────┘

  Your Workstation                      TrueNAS Server (NAS1-1)
  ┌──────────────┐                      ┌────────────────────┐
  │              │                       │                    │
  │  deploy_to_  │  1. Check ZFS        │  ✓ ZFS Available   │
  │  truenas.sh  │─────────────────────>│  ✓ Dataset Exists  │
  │              │                       │  ✓ System Ready    │
  │              │  2. Copy Scripts      │                    │
  │              │─────────────────────>│  /root/scripts/    │
  │              │                       │  ├─ tns_upd_size.sh│
  │              │  3. Test Script       │  └─ util/          │
  │              │─────────────────────>│     └─ logging.sh  │
  │              │                       │                    │
  │              │  4. Add Cron Job      │  crontab:          │
  │              │─────────────────────>│  */30 * * * *      │
  │              │                       │  tns_upd_size.sh   │
  └──────────────┘                      └────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                        RUNTIME PHASE                                 │
└─────────────────────────────────────────────────────────────────────┘

  TrueNAS Server (NAS1-1)               Client System (Your PC)
  ┌────────────────────┐                ┌──────────────────────┐
  │                    │                 │                      │
  │  Cron: Every 30min │                 │  Mount Point:        │
  │  ┌────────────┐    │                 │  /mnt/NAS1-1/        │
  │  │            │    │                 │    FieldsHm/         │
  │  │ tns_upd_   │    │                 │                      │
  │  │ size.sh    │    │    NFS/SMB      │  ┌─────────────┐    │
  │  │            │    │    Share        │  │             │    │
  │  └─────┬──────┘    │ <─────────────> │  │ dfc command │    │
  │        │           │                 │  │             │    │
  │        v           │                 │  └──────┬──────┘    │
  │  ┌─────────────┐   │                 │         │           │
  │  │ zfs list -r │   │                 │         v           │
  │  │ tpool/      │   │                 │  1. Run df          │
  │  │   FieldsHm  │   │                 │  2. Detect remote   │
  │  └─────┬───────┘   │                 │  3. Read .zfs_usage │
  │        │           │                 │  4. Show corrected  │
  │        v           │                 │     values          │
  │  Dataset Info:     │                 │                      │
  │  ├─ HASS: 1.2T     │                 │  Output:            │
  │  ├─ MEDIA: 7.1T    │                 │  //NAS1-1/FieldsHm  │
  │  ├─ acltest: 128K  │                 │  20T 8.3T 12T 41%   │
  │  └─ tmp: 7.5G      │                 │  ✓ CORRECT!         │
  │        │           │                 │                      │
  │        v           │                 └──────────────────────┘
  │  Write to:         │
  │  /mnt/tpool/       │
  │    FieldsHm/       │
  │    .zfs_usage_info │
  │                    │
  └────────────────────┘


┌─────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW                                     │
└─────────────────────────────────────────────────────────────────────┘

  TrueNAS                   NFS/SMB Mount              Client
  
  ZFS Datasets              Share Mount                df_color()
  ┌──────────┐             ┌──────────┐              ┌──────────┐
  │ HASS     │             │ FieldsHm │              │ Read     │
  │ 1.2T     │             │          │              │ .zfs_    │
  │          │             │          │              │ usage_   │
  │ MEDIA    │             │          │              │ info     │
  │ 7.1T     │    Export   │          │    Mount     │          │
  │          │────────────>│          │─────────────>│ Calculate│
  │ tmp      │             │          │              │ %        │
  │ 7.5G     │             │          │              │          │
  │          │             │ .zfs_    │              │ Display  │
  │ acltest  │             │ usage_   │              │ Correct  │
  │ 128K     │             │ info     │              │ Values   │
  └──────────┘             └──────────┘              └──────────┘
  
  Total: 8.3T used         Appears as                 Shows: 8.3T
         12T avail         single share               not 7.5G!


┌─────────────────────────────────────────────────────────────────────┐
│                        FILE STRUCTURE                                │
└─────────────────────────────────────────────────────────────────────┘

  Workstation (divtools/)
  ├── scripts/
  │   ├── truenas/
  │   │   ├── deploy_to_truenas.sh ────┐ Automated deployment
  │   │   ├── tns_upd_size.sh ─────────┤ Gets copied to TrueNAS
  │   │   ├── test_usage_correction.sh │ Test client setup
  │   │   ├── README.md ───────────────┤ Full documentation
  │   │   ├── QUICKSTART.md ───────────┤ Quick setup guide
  │   │   └── DEPLOYMENT_ENHANCEMENTS.md─┘ This enhancement summary
  │   └── util/
  │       ├── logging.sh ──────────────┐ Gets copied to TrueNAS
  │       └── truenas_usage.sh ────────┘ Used by df_color()
  └── dotfiles/
      └── .bash_profile ───────────────┐ Enhanced df_color()

  TrueNAS (/root/scripts/)
  ├── tns_upd_size.sh ─────────────────┐ Runs via cron
  └── util/
      └── logging.sh

  Mount Point (/mnt/NAS1-1/FieldsHm/)
  └── .zfs_usage_info ─────────────────┐ Read by clients


┌─────────────────────────────────────────────────────────────────────┐
│                     CONFIGURATION POINTS                             │
└─────────────────────────────────────────────────────────────────────┘

  deploy_to_truenas.sh (Top of script)
  ┌───────────────────────────────────────────┐
  │ UPDATE_INTERVAL_MINUTES=30                │ ← Change this
  │ ZFS_PARENT_DATASET="tpool/FieldsHm"       │ ← Change this
  │ EXPORT_FILENAME=".zfs_usage_info"         │ ← Change this
  └───────────────────────────────────────────┘
  
  Usage:
  ./deploy_to_truenas.sh -h NAS1-1           # Deploy
  ./deploy_to_truenas.sh -h NAS1-1 -test     # Test mode
  ./deploy_to_truenas.sh --skip-cron         # No auto-cron
```

---
Last Updated: 11/4/2025 10:35:00 PM CST
