#!/bin/bash
# Quick test to verify section headers display correctly
# Last Updated: 01/15/2026 11:35:00 PM CST

cd /home/divix/divtools/projects/ads

echo "Testing dt_ads_native.sh wrapper..."
echo "Section headers should be visible and styled differently from menu items."
echo "Press Enter to launch the menu (then press ESC to exit)..."
read

/home/divix/divtools/scripts/ads/dt_ads_native.sh --test

echo ""
echo "Did you see the section headers?"
echo "  - ═══ INSTALLATION ═══"
echo "  - ═══ INSTALL GUIDE: [realm] ═══"
echo "  - ═══ DOMAIN SETUP ═══"
echo "  - ═══ SERVICE MANAGEMENT ═══"
echo "  - ═══ DIAGNOSTICS ═══"
echo ""
echo "They should appear centered, bold, and in a different color."
