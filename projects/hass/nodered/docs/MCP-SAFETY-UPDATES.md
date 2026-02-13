# MCP Safety Updates - Critical Protection Against Data Loss

**Date:** 2025-11-20  
**Incident:** Accidental deletion of all Node-RED flow tabs due to unsafe use of `update-flows`  
**Resolution:** Comprehensive safety guardrails added across all documentation

---

## 🔒 Files Updated with Safety Requirements

### 1. `.github/copilot-instructions.md` - Added Critical MCP Safety Section

**Location:** New section "⚠️ CRITICAL: MCP Server Safety Rules" (lines ~150-220)

**Content:**
- Absolute rule: Always choose single-item update operations over replace-all operations
- Why replace-all is dangerous: deletes all data not explicitly included
- Implementation steps: Retrieve ALL items first, merge changes, then update
- Safe pattern examples with code
- MCP Tools Checklist for verification before executing operations

**Impact:** Every future MCP operation will be guided by these rules in the main workspace instructions.

---

### 2. `projects/hass/nodered/AGENTS.md` - Updated Flow Management Tools Documentation

**Changes:**

**Section 1: Flow Management Tools Table (Line ~25)**
- Updated `update-flows` description: "⚠️ **DANGEROUS**: Replaces ALL flows - use carefully"
- Updated `update-flow` description: "✅ **SAFE**: Update single flow by ID" with "(RECOMMENDED)"
- Added visual emphasis to guide away from dangerous operations

**Section 2: New Safety Warning Before update-flows Examples (Line ~680)**
- Added "⚠️ CRITICAL: update-flows Safety Rules" section
- Explains that `update-flows` REPLACES ENTIRE ARRAY
- Shows WRONG (unsafe) example: calling with only new flows
- Shows RIGHT (safe) example: merge with all existing flows first
- Recommends PREFERRED alternative: use `update-flow` for single updates
- Includes 3 clear code examples showing comparison

**Impact:**
- Any AI working on Node-RED flows will see this warning prominently
- Provides concrete code examples of safe vs unsafe patterns
- Makes the preferred method (update-flow) explicit

---

### 3. `projects/hass/nodered/docs/FLOW-LIST.md` - Added Deployment Safety Section

**Location:** New section "⚠️ CRITICAL: Flow Deployment Safety" (after Overview)

**Content:**
- Clear checkmarks (✅) for safe operations
- Clear X marks (❌) for dangerous operations
- Step-by-step safe deployment method
- Reference to AGENTS.md for detailed examples
- Positioned prominently before any flow deployment instructions

**Impact:**
- Every time flows need to be deployed, this safety section is visible
- Users and AI are reminded before execution what the safe approach is
- Acts as a secondary safety check before dangerous operations

---

## 📋 Safety Checklist - Before Any MCP Operation

Every MCP Server operation must now satisfy this checklist:

- [ ] Is there a "single item" operation option available?
  - YES → Use single-item operation (STOP HERE - SAFE)
  - NO → Continue to next question
  
- [ ] Am I replacing or updating ALL items in a collection?
  - YES → Did I first retrieve ALL existing items?
    - YES → Did I merge my changes into the complete set?
      - YES → Safe to proceed with update-all operation
      - NO → Go back and retrieve all items, merge, then update
    - NO → Go back and retrieve ALL items first
  - NO → Use single-item operation

---

## 🎯 Key Safety Principles Established

1. **Default to Single-Item Operations**
   - `update-flow` instead of `update-flows`
   - `update-node` instead of updating all nodes
   - `update-item` instead of replace-all

2. **Merge Before Replacing**
   - Always retrieve current state first
   - Merge changes into complete set
   - Replace with merged data

3. **Verification Checkpoints**
   - Verify tool choice before execution
   - Verify all items included in replacement
   - Verify operation result matches expectations

4. **Documentation Hierarchy**
   - Workspace-level rules in copilot-instructions.md (applies to all projects)
   - Project-level examples in AGENTS.md (specific to Node-RED)
   - Usage guidelines in FLOW-LIST.md (when to apply them)

---

## 🔍 Rules by MCP Server Type

### Node-RED Flows (This Project)
- **Safe Single-Item Operations:**
  - `update-flow` - Update individual flow by ID
  - `create-flow` - Create new flow tab
  - `delete-flow` - Delete flow by ID
  - `update-node` - Update single node (if available)

- **Dangerous Batch Operations:**
  - `update-flows` - Only safe if ALL flows retrieved and merged first
  - Any operation updating multiple items simultaneously

- **Read-Only (Safe Anytime):**
  - `get-flows`, `get-flow`, `get-flows-formatted`
  - `get-nodes`, `get-node-info`, `search-nodes`
  - `get-diagnostics`, `get-settings`, `visualize-flows`

### General Rule for Any MCP Server
- Single-item operations: Always safe
- Batch operations: Require explicit merge of existing items
- Replace-all operations: Forbidden unless explicitly confirmed all items included

---

## 📚 Documentation References

| Document | Section | Purpose |
|----------|---------|---------|
| `.github/copilot-instructions.md` | ⚠️ CRITICAL: MCP Server Safety Rules | Workspace-wide MCP safety requirements |
| `projects/hass/nodered/AGENTS.md` | ⚠️ CRITICAL: update-flows Safety Rules | Node-RED specific safe patterns with code examples |
| `projects/hass/nodered/AGENTS.md` | Flow Management Tools Table | Tool-by-tool safety ratings |
| `projects/hass/nodered/docs/FLOW-LIST.md` | ⚠️ CRITICAL: Flow Deployment Safety | Pre-deployment safety checklist |

---

## ✅ Verification Checklist

The following have been updated and verified:

- [x] Workspace-level MCP safety rules added to copilot-instructions.md
- [x] Node-RED project-level safety section added to AGENTS.md
- [x] Flow deployment safety section added to FLOW-LIST.md
- [x] Tool table updated with safety indicators (✅ safe, ⚠️ dangerous)
- [x] Code examples provided for safe vs unsafe patterns
- [x] Multiple documentation layers provide reinforcement
- [x] Clear guidance on when to use each tool

---

## 🎓 Lessons Learned

1. **Batch operations are dangerous by default** - They require explicit merging of existing state
2. **Single-item operations should be the default** - They're safer and more precise
3. **Safety must be documented at multiple levels** - Workspace, project, and task-specific
4. **Verification checkpoints prevent disasters** - A simple checklist before execution could have prevented this incident

---

## 🔮 Future Prevention

Future MCP servers added to this workspace should follow the same pattern:

1. Provide single-item update operations when possible
2. If batch operations exist, require merging of existing state in documentation
3. Add safety warnings to all destructive operations
4. Document safe patterns with code examples
5. Update copilot-instructions.md with tool-specific safety rules

---

**Status:** ✅ All safety updates complete. Ready to restore Node-RED flows with these protections in place.
