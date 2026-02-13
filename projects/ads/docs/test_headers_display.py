#!/usr/bin/env python3
"""
Standalone test to verify headers display correctly in DtpMenuApp.
This creates a complete menu with headers and items and renders it to see
what the user will actually see.
"""

import sys
from pathlib import Path

# Add dtpyutil to path
dtpyutil_path = Path(__file__).parent.parent.parent / "dtpyutil" / "src"
sys.path.insert(0, str(dtpyutil_path))

# Add scripts/ads to path
scripts_ads = Path(__file__).parent.parent.parent.parent / "scripts" / "ads"
sys.path.insert(0, str(scripts_ads))

from dtpyutil.menu.dtpmenu import DtpMenuApp

# Create menu matching the actual ADS native setup menu structure
test_items = [
    ("", "═══ INSTALLATION ═══"),
    ("1", "Install Samba (Native)"),
    ("2", "Configure Environment Variables"),
    ("3", "Check Environment Variables"),
    ("4", "Create Config File Links (for VSCode)"),
    ("5", "Install Bash Aliases"),
    ("", "═══ INSTALL GUIDE: AVCTN.LAN ═══"),
    ("6", "Generate Installation Steps Doc"),
    ("7", "Update Installation Steps Doc"),
    ("", "═══ DOMAIN SETUP ═══"),
    ("8", "Provision AD Domain"),
    ("9", "Configure DNS on Host"),
    ("", "═══ SERVICE MANAGEMENT ═══"),
    ("10", "Start Samba Services"),
    ("11", "Stop Samba Services"),
    ("12", "Restart Samba Services"),
    ("13", "View Service Logs"),
    ("", "═══ DIAGNOSTICS ═══"),
    ("14", "Run Health Checks"),
    ("", "═════════════════════════════"),
    ("0", "Exit"),
]

async def test_menu_visual():
    """Test the menu rendering"""
    print("=" * 80)
    print("TESTING: DtpMenuApp with Headers (Real ADS Menu)")
    print("=" * 80)
    
    app = DtpMenuApp(
        mode="menu",
        title="Samba AD DC Native Setup (15)",
        content_data=test_items,
        width=80,
        height=0,
        colors=None,
    )
    
    async with app.run_test(size=(90, 40)) as pilot:
        menu_list = app.query_one("#menu-list")
        
        print("\n✅ Menu rendered successfully!")
        print(f"✅ Total items in ListView: {len(list(menu_list.children))}")
        
        # Count and display items
        header_count = 0
        selectable_count = 0
        
        print("\nMenu Content:")
        print("-" * 80)
        
        for idx, item in enumerate(menu_list.children):
            label_widget = item.children[0]
            rendered = str(label_widget.render())
            item_id = item.id
            
            if item_id.startswith("header-"):
                header_count += 1
                print(f"  {rendered}")  # Headers should show centered
            else:
                selectable_count += 1
                print(f"  {rendered}")
        
        print("-" * 80)
        print(f"\n✅ Summary:")
        print(f"   Headers found: {header_count}")
        print(f"   Selectable items: {selectable_count}")
        print(f"   Total: {header_count + selectable_count}")
        
        if header_count == 6:
            print(f"\n✅✅✅ SUCCESS! All 6 headers are present and should be visible!")
        else:
            print(f"\n❌ ERROR: Expected 6 headers, found {header_count}")

if __name__ == "__main__":
    import asyncio
    asyncio.run(test_menu_visual())
