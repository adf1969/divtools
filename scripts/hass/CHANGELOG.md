# Changelog - Home Assistant Scripts
# Last Updated: 11/25/2025 1:36:00 PM CST

## 2025-11-25 - Refactoring and Label Support

### Added
- **hass_util.py** - New utility module with reusable Home Assistant API functions
  - Can be run independently to list areas and labels
  - Supports `--lsa`/`--ls-areas` to list all areas with labels
  - Supports `--lsl`/`--ls-labels` to list all labels
  - Provides `get_ha_config()` for centralized authentication
  - Provides `fetch_areas_via_websocket()` and `fetch_labels_via_websocket()`
  - Provides `slugify()` for consistent name normalization

### Changed
- **gen_presence_sensors.py** - Refactored to use hass_util module
  - Removed duplicate code (auth, websocket fetching, slugify)
  - Imports functions from hass_util for cleaner code
  - Added `--exclude-labels` argument to filter areas by label
  - Updated area table to show labels column
  - Uses area_id for stable identification (slug_id can change with renames)

### Notes
- area_id is stable and should be used for identification
- area_slug is derived from area name and can change
- Labels attached to areas can be used to exclude them from sensor generation

---

#IDEA