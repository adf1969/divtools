# Manual Test Plan for Bug Fixes

**Date:** 2026/01/15  
**Tester:** User

## Test 1: Check Env Vars Display

**Bug:** Selecting "Check Environment Variables" caused immediate flash/exit without showing data

**Expected Fix:** Should display environment variables in a message box

**Test Steps:**
1. Run: `cd /home/divix/divtools/scripts/ads && /home/divix/divtools/scripts/venvs/dtpyutil/bin/python dt_ads_native.py`
2. Select "Check Environment Variables" from main menu
3. **Expected:** Message box appears showing:
   - SITE_NAME
   - HOSTNAME
   - DOCKER_HOSTDIR
   - ADS_DOMAIN
   - ADS_REALM
   - ADS_ADMINPASS
   - Other environment variables
4. **Expected:** Click OK returns to main menu (not exits)

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_______________________________________________________________________

---

## Test 2: Dynamic Dialog Height

**Bug:** Dialog boxes had hardcoded `height: 50` causing oversized dialogs

**Expected Fix:** Dialogs should auto-size to content with `height: auto`

**Test Steps:**
1. Run same application
2. Navigate through multiple menu options:
   - Main menu (should be compact, not 50 lines tall)
   - Check Env Vars (should fit content + buttons + padding)
   - Any msgbox/yesno dialogs (should be appropriately sized)
3. **Expected:** Each dialog sized to fit its content
4. **Expected:** No excessive whitespace at bottom
5. **Expected:** Max height capped at 90% screen

**Result:** [ ] PASS / [ ] FAIL

**Notes:**
_______________________________________________________________________

---

## Automated Test Coverage

**Test Suite:** `test/test_dt_ads_features.py`  
**Status:** ✅ All 23 tests passing (1.76s)

**Missing Coverage:**
- [ ] Test for check_env_vars() msgbox display (add to test_dt_ads_features.py)
- [ ] Visual test for dynamic height (requires manual verification)

