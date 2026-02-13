# Node-RED Project - Development History & Decisions

## Project Overview

The Node-RED project for Home Assistant is a collection of automation, monitoring, notification, and integration flows that enhance the capabilities of the Home Assistant instance. This document tracks the architectural decisions, design patterns, and development history.

---

## Outstanding Questions & Decisions

### ❓ OUTSTANDING - Q1: Flow Organization Structure
**Question:** How should Node-RED flows be organized on disk - by flow type/purpose or by a flat structure with flow type metadata?

**Options:**
- **Option A**: Hierarchical by category (`flows/automation/`, `flows/monitoring/`, `flows/notifications/`, etc.)
  - Pros: Easy to locate flows by purpose, scales well with many flows
  - Cons: Requires upfront categorization
  
- **Option B**: Flat structure with all flows in `flows/` directory
  - Pros: Simple, single source of truth in FLOW-LIST.md
  - Cons: Can become cluttered with many flows
  
- **Option C**: Hybrid - Primary category folders with sub-folders for complex flows
  - Pros: Balance between organization and simplicity
  - Cons: Requires clear guidelines for when to subdivide

**Context/Impact:** This decision affects how flows are discovered, maintained, and documented. A clear structure improves team collaboration and reduces cognitive load when managing multiple flows.

### Answer
**Decision:** Option A - Hierarchical organization by category

Flow organization should follow a category-based structure within `flows/[category]/[flow-name].json`. This approach:
- Aligns with the FLOW-LIST.md categories (Automation, Notification, Monitoring, Integration, Data Processing)
- Makes it intuitive to find related flows
- Scales well as the flow collection grows
- Separates concerns by functional purpose

Each category folder should contain flows related to that domain, and the FLOW-LIST.md registry serves as the master index.

---

### ❓ OUTSTANDING - Q2: MCP Integration for Node-RED
**Question:** Should we implement MCPs (Model Context Protocol servers) for Home Assistant and Node-RED integration?

**Options:**
- **Option A**: Implement both read-only Home Assistant MCP and read-write Node-RED MCP
  - Pros: Direct integration with AI tools, easier flow creation and testing
  - Cons: Adds complexity, requires MCP server infrastructure
  
- **Option B**: Maintain flows as JSON files only
  - Pros: Simple, version-controllable, portable
  - Cons: Manual export/import workflow, harder to test programmatically
  
- **Option C**: Implement Node-RED MCP only (skip Home Assistant MCP for now)
  - Pros: Focuses on flow creation/modification, can defer HASS integration
  - Cons: Limited context about HASS state and capabilities

**Context/Impact:** MCPs would enable programmatic flow creation and testing but require additional infrastructure. This affects development workflow and tool integration.

### Answer

**Decision:** To be determined after assessing MCP availability and integration complexity

This decision should consider:
1. Availability of existing Home Assistant MCPs (check MCP registry)
2. Node-RED MCP availability or need for custom implementation
3. Integration complexity with current divtools infrastructure
4. Value proposition for the development workflow

---

### ❓ OUTSTANDING - Q3: Flow Testing Strategy
**Question:** How should Node-RED flows be tested before deployment?

**Options:**
- **Option A**: Manual testing in Node-RED test environment
  - Pros: No additional tooling, intuitive
  - Cons: Not easily automated, hard to create test cases
  
- **Option B**: Export flows with test injection nodes for dry-run testing
  - Pros: Can verify flow logic with simulated inputs
  - Cons: Requires discipline in creating test flows
  
- **Option C**: JSON schema validation + manual Node-RED testing
  - Pros: Catches structural issues, still allows manual verification
  - Cons: Cannot verify runtime behavior without execution

**Context/Impact:** Testing approach affects how confident we can be that flows work correctly before importing to production Home Assistant instance.

### Answer
**Decision:** Pending - will be determined after initial flows are created

Testing strategy should be established once we have concrete flows to test. Consider starting with Option B (test injection nodes) as flows are developed.

---

## Chat Session History

### Session 1: 2025-11-19 - Initial Project Structure Setup
- **Objective**: Review and reformat NODERED-PROJECT.md with implementation guidance
- **Tasks Completed**:
  - Reformatted HASS-SERVER-INFO.md with proper MD structure and update history tracking
  - Created FLOW-LIST.md with comprehensive registry table and category definitions
  - Created NODERED-PROJECT-HISTORY.md (this file)
  - Established folder structure recommendations
  - Documented outstanding questions for future decisions

- **Decisions Made**:
  - Adopted hierarchical flow organization by category
  - Deferred MCP decision pending further investigation
  - Deferred testing strategy until flows are in development

- **Next Steps**:
  - Create AGENTS.md for the Node-RED project
  - Create folder structure: `flows/automation/`, `flows/monitoring/`, `flows/notifications/`, `flows/integration/`, `flows/data_processing/`
  - Begin defining first set of flows in FLOW-LIST.md

---

## Architectural Notes

### File Organization
```
projects/hass/nodered/
├── AGENTS.md                    # Project guidelines
├── docs/
│   ├── NODERED-PROJECT.md      # Original requirements (archived)
│   ├── HASS-SERVER-INFO.md     # HASS/Node-RED versions with history
│   ├── FLOW-LIST.md            # Master registry of all flows
│   └── NODERED-PROJECT-HISTORY.md  # This file
├── flows/
│   ├── automation/
│   ├── monitoring/
│   ├── notifications/
│   ├── integration/
│   └── data_processing/
└── tests/
    └── flow_tests/
```

### Integration Points
- **Home Assistant**: Flows interact with HASS entities, automations, and services
- **Node-RED**: Flow development and management
- **divtools**: Part of the broader divtools monorepo

---

## Design Patterns & Best Practices

### Flow Naming Conventions
- Use descriptive names: `living_room_motion_alert` vs `flow1`
- Include purpose in name: `backup_notification`, `temperature_monitor`
- Avoid timestamps in names (use FLOW-LIST.md for versioning)

### Flow JSON Comments
- Export flows with descriptions in Node-RED
- Include purpose statement at top of flow
- Document dependencies on HASS entities or integrations

### Version Management
- Use semantic versioning in FLOW-LIST.md
- Update "Last Modified" date on each change
- Keep JSON files in version control for audit trail

---

## References
- Home Assistant Documentation: https://www.home-assistant.io/
- Node-RED Documentation: https://nodered.org/docs/
- divtools AGENTS.md: `/home/divix/divtools/projects/dthostmon/AGENTS.md`