# Home Assistant Node-RED Project

## Project Description

This is a Node-RED sub-project within divtools focused on creating and managing automation flows for Home Assistant. The project includes flow definitions, documentation, and integration guidelines for a Node-RED instance integrated with Home Assistant.

---

## Project Scope

### Objectives
- Create reusable Node-RED flows for Home Assistant automation and monitoring
- Organize flows by category/purpose for easy discovery and maintenance
- Track flow versions and modifications over time
- Enable team collaboration on flow development
- Establish integration with divtools infrastructure

### Supported Categories
- **Automation**: Device control and scene management
- **Notification**: Alerts and message delivery
- **Monitoring**: System state tracking and reporting
- **Integration**: External service connections
- **Data Processing**: Data transformation and aggregation

---

## Project Status

| Component | Status | Version | Last Updated |
|-----------|--------|---------|--------------|
| Project Structure | ✅ Complete | 1.0 | 2025-11-19 |
| Documentation | ✅ Complete | 1.0 | 2025-11-19 |
| AGENTS.md | ✅ Complete | 1.0 | 2025-11-19 |
| Flows | 🔵 Pending | - | - |
| MCP Integration | ❓ Deferred | - | - |

---

## Documentation Files

### Core Project Files
- **AGENTS.md** - Project guidelines and best practices
- **HASS-SERVER-INFO.md** - Server versions and configuration history
- **FLOW-LIST.md** - Master registry of all Node-RED flows
- **NODERED-PROJECT-HISTORY.md** - Development decisions and chat history
- **NODERED-PROJECT.md** - This file

### Supporting Files
See `NODERED-PROJECT-HISTORY.md` for:
- Architectural decisions
- Outstanding questions
- Design patterns and conventions
- Development workflow notes

---

## Getting Started

### 1. Review Documentation
1. Read `AGENTS.md` for project guidelines
2. Check `HASS-SERVER-INFO.md` for current versions
3. Review `NODERED-PROJECT-HISTORY.md` for design decisions

### 2. Create New Flows
1. Plan flow in FLOW-LIST.md (add to registry)
2. Create flow in Node-RED
3. Test thoroughly in test environment
4. Export JSON file to appropriate `flows/[category]/` folder
5. Update FLOW-LIST.md with version and file location

### 3. Update Version History
When making changes:
1. Update FLOW-LIST.md with new version and date
2. Increment version number (MAJOR.MINOR.PATCH)
3. Document changes in NODERED-PROJECT-HISTORY.md if architectural

---

## Folder Structure

```
projects/hass/nodered/
├── AGENTS.md
├── docs/
│   ├── NODERED-PROJECT.md          # This file
│   ├── HASS-SERVER-INFO.md         # Server configuration & history
│   ├── FLOW-LIST.md                # Master flow registry
│   └── NODERED-PROJECT-HISTORY.md  # Decisions & chat history
├── flows/                          # Node-RED flow JSON files
│   ├── automation/
│   ├── monitoring/
│   ├── notifications/
│   ├── integration/
│   └── data_processing/
└── tests/                          # Test flows and test data
    └── flow_tests/
```

---

## Key Design Decisions

For detailed information on design decisions, see `NODERED-PROJECT-HISTORY.md`:

1. **Flow Organization**: Hierarchical by category (Automation, Monitoring, etc.)
2. **Version Tracking**: Semantic versioning in FLOW-LIST.md
3. **Testing**: Strategy to be determined as flows are developed
4. **MCP Integration**: Deferred pending investigation

---

## Next Steps

1. ✅ Create project documentation structure
2. ✅ Establish flow registry and categories
3. 🔵 Define first set of flows (Automation, Monitoring)
4. 🔵 Create folder structure
5. 🔵 Develop and test flows
6. 🔵 Implement MCP integration (if beneficial)
7. 🔵 Establish testing procedures

---

## References

- **Home Assistant**: https://www.home-assistant.io/
- **Node-RED**: https://nodered.org/
- **divtools**: See parent directory documentation
- **Project History**: See `NODERED-PROJECT-HISTORY.md`
