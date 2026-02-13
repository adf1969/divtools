# Node-RED Flows

This directory contains all Node-RED flow JSON files organized by category.

## Category Folders

### automation/
Home automation flows that control devices, manage scenes, and trigger actions based on conditions.

**Examples:**
- Motion-triggered lighting
- Scene management and transitions
- Scheduled automation tasks
- Device control workflows

**File naming:** `[flow_purpose].json` (e.g., `living_room_motion_alert.json`)

---

### monitoring/
Flows that track system state, collect metrics, and generate monitoring data.

**Examples:**
- Temperature and humidity monitoring
- Energy consumption tracking
- System status dashboards
- State change tracking

**File naming:** `[metric_name]_monitor.json` (e.g., `temperature_monitor.json`)

---

### notifications/
Flows that generate and deliver alerts, notifications, and messages to various channels.

**Examples:**
- Mobile push notifications
- Email alerts
- Log file notifications
- Status updates to external services

**File naming:** `[channel]_[event].json` (e.g., `mobile_motion_alert.json`)

---

### integration/
Flows that connect external services, APIs, and data sources with Home Assistant.

**Examples:**
- Weather data integration
- Calendar synchronization
- API endpoint connections
- External service webhooks

**File naming:** `[service]_[purpose].json` (e.g., `weather_forecast_integration.json`)

---

### data_processing/
Flows that transform, aggregate, and process data from multiple sources.

**Examples:**
- Data aggregation and summarization
- Log file processing
- Statistical calculations
- Data format conversions

**File naming:** `[process_name].json` (e.g., `energy_daily_aggregation.json`)

---

## Flow Export Format

All flows are stored as Node-RED JSON exports. To import a flow:

1. Open Node-RED editor
2. Click hamburger menu → Import
3. Select JSON file from this directory
4. Review imported flow for dependencies and entity IDs
5. Update any HASS entity IDs as needed for your instance
6. Deploy flow

## Flow Naming Conventions

- Use **snake_case** for file names
- Include **category descriptor** in name (e.g., `_automation`, `_monitor`)
- Use **descriptive names** that explain purpose
- Avoid timestamps or version numbers in filenames (use FLOW-LIST.md for versioning)

## Documentation

For flow registry and metadata, see:
- **FLOW-LIST.md** - Master registry of all flows with versions and status
- **AGENTS.md** - Development guidelines and best practices
- **NODERED-PROJECT-HISTORY.md** - Architectural decisions

## Adding New Flows

1. Create flow in Node-RED
2. Add to FLOW-LIST.md registry
3. Export as JSON
4. Save to appropriate category folder
5. Update FLOW-LIST.md with file path and version
6. Document any dependencies in flow description