#!/usr/bin/env python3
"""Quick test script to verify dtpyutil imports work correctly"""

try:
    from dtpyutil.menu import DtpMenuApp
    print("✅ Import successful!")
    print(f"   DtpMenuApp class: {DtpMenuApp}")
except Exception as e:
    print(f"❌ Import failed: {e}")
    import sys
    print(f"   Python path entries:")
    for p in sys.path:
        print(f"     - {p}")
