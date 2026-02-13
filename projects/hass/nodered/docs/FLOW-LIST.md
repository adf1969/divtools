# Node-RED Flow List

[TOC]

## Overview

This document maintains a comprehensive list of all Node-RED flows designed for the Home Assistant Node-RED integration. Each flow is tracked with its purpose, implementation status, version, and location.

This serves as both:
- A **planning document** for brainstorming and defining new flows
- A **tracking system** for flow versions, modifications, and implementation status

---

## ⚠️ CRITICAL: Flow Deployment Safety

**When deploying flows to Node-RED:**

- ✅ **ALWAYS use `update-flow`** to update individual flows by ID
- ✅ **ALWAYS use `create-flow`** to add new flows
- ❌ **NEVER use `update-flows`** unless you have retrieved ALL existing flows first and merged your changes into them
- ❌ **NEVER use `mcp_nodered-dt_update-flows` with only your new/modified flows** - this will DELETE all other flows

**Safe Deployment Method:**
1. Get ALL existing flows: `get-flows`
2. Merge your updated/new flows into the complete set
3. Call `update-flows` with the merged array containing everything
4. Verify all flows are present in Node-RED

**See AGENTS.md for detailed examples and safe patterns.**

---

## How To Use This Document

### Adding a NEW Flow

1. **Create a Flow Definition Entry**: Add a new `### Flow Name` section in the **[Flow Definitions](#flow-definitions)** section below, using the template from an existing flow (e.g., Shop Light - Motion → Light).
   - Include all relevant metadata: Purpose, Inputs & Entities, Primary Triggers, Core Logic, Node List, Test Cases
   - Set **Status** to "Planning" initially

2. **Execute the Flow Implementation Prompt**: Once you've added the Flow Definition, run the following prompt with the AI:

   > **Prompt:** Read the Flow Definition entries in `/home/divix/divtools/projects/hass/nodered/docs/FLOW-LIST.md` and implement any flows marked as "Planning" or "In Development". For each flow, perform these steps:
   > 1. Add entry to Flow Registry table (if not already there)
   > 2. Review entity_ids and device_ids from Home Assistant using the `hass_api_wrapper.sh` script
   > 3. Create the Node-RED JSON flow file (use existing flows as templates)
   > 4. Update the flow status to "Testing" and Last Modified date
   > 5. Import the flow into the Node-RED instance
   > 6. Return a summary of what was implemented

   The AI will:
   - Add the flow to the **Flow Registry** table automatically
   - Query Home Assistant for required entity IDs and device information
   - Create the JSON file in `flows/[category]/[flow_name].json`
   - Update the FLOW-LIST with the implementation file path and status
   - Import the flow into Node-RED (requires Node-RED access)

   Once the Flow has been tested, change the flow status to "Completed".

### Adding Functionality to an EXISTING Flow

1. **Update the Flow Definition**: Edit the appropriate `### Flow Name` section in **[Flow Definitions](#flow-definitions)**:
   - Update the **Purpose** or **Core Logic/Mapping** section with new details
   - Update **Status** to "In Development" if you're working on changes
   - Increment the **Version** (use semantic versioning: MAJOR.MINOR.PATCH)
   - Update **Last Modified** date

2. **Execute the Flow Update Prompt**: Run this prompt with the AI:

   > **Prompt:** Update the Node-RED flow implementation for "[Flow Name]" based on the Flow Definition in `/home/divix/divtools/projects/hass/nodered/docs/FLOW-LIST.md`. The flow definition has been updated with new requirements. Please:
   > 1. Review the updated Flow Definition
   > 2. Identify what changes need to be made to the Node-RED flow
   > 3. Update the JSON file at `flows/[category]/[flow_name].json` with the changes
   > 4. Re-import the flow into Node-RED
   > 5. Update the Flow Registry with the new version and last modified date
   > 6. Return a summary of the changes made

   The AI will:
   - Review your Flow Definition changes
   - Modify the JSON flow file accordingly
   - Reload the flow in Node-RED
   - Update the Flow Registry with the new version

### Implementation Prompts Reference

For detailed implementation procedures and Node-RED-specific instructions, see **[AGENTS.md](../AGENTS.md#implementation-procedures)** → **Implementation Procedures** section.

### Handling Flow Testing Issues (Test Review Workflow)

When you've tested a flow and found issues or areas needing clarification, use this streamlined workflow:

#### The Testing Prompt

Run this prompt with the AI to efficiently address all issues from your flow tests:

> **Prompt:** Review the most recent Flows that were tested in `/home/divix/divtools/projects/hass/nodered/docs/FLOW-LIST.md`.
>
> For each flow with TESTING issues marked as "Active" or "BROKEN":
> 1. **Analyze**: Read the issue description and understand what needs to be resolved
> 2. **Investigate**: Determine root causes (missing node types, unclear functionality, logic errors, etc.)
> 3. **Resolve**: Apply the solution by:
>    - Updating JSON files with corrected node types or logic
>    - Re-importing corrected flows to Node-RED via manual import
>    - Marking issues as "Fixed" with timestamp in FLOW-LIST.md
> 4. **Document**: Update FLOW-LIST.md TESTING sections with resolution details
> 5. **Return**: Summary of what was fixed and ready for your manual verification
>
> After fixes are applied and verified working in Node-RED, manually update the Flow Registry status from "Completed" to "Active" (or to "Production" if applicable).

#### TESTING Section Structure

Each flow's **TESTING** section has this structure:
```
**TESTING:**
- Test 1:  (First round of testing)
  - Issue 1: [Description]
    - **Status:** Active | Answered | Fixed
    - Details about the issue
  - Issue 2: [Description]
    - **Status:** Active | Answered | Fixed
    - Details about the issue
- Test 2:  (Second round of testing, if needed after fixes)
  - Issue 1: [Description]
    - **Status:** Active | Answered | Fixed
```

#### Status Meanings

- **Active**: Issue identified but not yet addressed. AI should investigate and propose resolution.
- **BROKEN**: Critical issue that prevents flow from functioning. Same priority as "Active" - AI should investigate and propose resolution immediately.
- **Answered**: Investigation complete, solution documented. AI should apply the fix to JSON/Node-RED.
- **Fixed**: Issue resolved and verified. Include timestamp (YYYY-MM-DD) and brief summary of the fix.

#### Common Issue Types & Resolution Approaches

| Issue Type               | Root Cause                                     | Resolution                                                              |
| ------------------------ | ---------------------------------------------- | ----------------------------------------------------------------------- |
| **Node Type Mismatch**   | Generated JSON with incorrect node type names  | Update JSON: `"type": "old-name"` → `"type": "correct_name"`, re-import |
| **Missing Node Types**   | Node type doesn't exist in Node-RED instance   | Check if extension installed, or use alternative node type              |
| **Unclear Node Purpose** | Debug node or unusual config not documented    | Clarify what the node does and why it's included in the flow            |
| **Logic Error**          | Flow logic doesn't match intended behavior     | Fix function node code, update switch conditions, adjust timing         |
| **Missing Entity**       | Referenced Home Assistant entity doesn't exist | Update entity_id in flow to match actual Home Assistant entity          |
| **Connection Issue**     | Node not wired to next node or output mismatch | Update `wires` array in JSON to fix node connections                    |

#### Quick Reference: JSON Corrections

Most common corrections can be done via find-replace in the JSON files:

```bash
# Node type corrections (most common)
"type": "current-state"    → "type": "current_state"
"type": "ha-call-service"  → "type": "action"
"type": "wait"             → "type": "trigger" with "type": "wait" property

# Entity ID corrections
"entity_id": "wrong.entity" → "entity_id": "correct.entity"

# Wire connection fixes
"wires": [[]]              → "wires": [["next_node_id"]]
```

---

## Flow Registry

| Flow Name                                                           | Flow Tab                        | Category   | Status    | Version | Last Modified | Implementation File                       |
| ------------------------------------------------------------------- | ------------------------------- | ---------- | --------- | ------- | ------------- | ----------------------------------------- |
| [Shop Light - Motion → Light](#shop-light---motion--light)          | Shop Light - Motion             | Automation | Completed | 1.0.0   | 2025-11-20    | `flows/automation/shop_light_motion.json` |
| [Bug Zapper Plug - Night Control](#bug-zapper-plug---night-control) | Bug Zapper Plug - Night Control | Automation | Completed | 1.0.0   | 2025-11-20    | `flows/automation/bug_zapper_plug.json`   |

---

## Flow Definitions

### Shop Light - Motion → Light
[Back to Registry](#flow-registry)

**Flow Tab:** Shop Light - Motion
**Category:** Automation
**Status:** Planned (Migrate from HASS Automation)
**Version:** 1.0.0
**Last Modified:** 2025-11-20
**Implementation File:** `flows/automation/shop_light_motion.json`

**Purpose:**
Motion -> Light with day/night timeouts + debounce

**Inputs & Entities:**
- Motion/Occupancy: `binary_sensor.c04_ac_shop_cell_motion_detection` (or other occupancy binary_sensor)
- Light: `light.shop_light_switch_outlet` (supports ON/OFF, optionally transition)
- Illuminance: optional sensor entity (e.g., `sensor.shop_illuminance_lux`) + lux threshold number
- Timer / Debounce: `timer.shop_light_ignore_timer` (optional in HA) — Node-RED can emulate debounce using flow context + 'delay' node.
- Night/Day: `input_datetime.night_time_start`, `input_datetime.night_time_end`

**Primary Triggers:**
- `events: state` node listening for motion ON (trigger) and OFF (release). Use server-state-changed with the property `to: 'on|off'` as necessary.
- `current state` node for lux checks (optional) and to check debounce state for the timer.

**Core Logic/Mapping:**
1. `events: state` (motion): when motion -> function that checks `lux` (if lux sensor present)
2. If lux OK and debounce timer is idle -> `call service` light.turn_on (optionally set brightness)
3. Use `trigger` node in restart mode that, on receiving motion, waits for a computed time (day timeout or night timeout minus dim-before-off) and then sends an output to call-service to light.turn_off (use transition as `dim_time` if supported)
4. If additional motion arrives while waiting, the `trigger` node is reset (restart mode), effectively restarting the countdown.
5. After turning the light off, optionally call `timer.start` helper or use flow context and start a short `delay` (debounce) to prevent the light itself from retriggering the motion sensor.
6. For `night` detection: use a `time-range-switch` (node-red-contrib-time-range-switch) or a `function` node that checks `now` against `input_datetime.night_time_start` / `night_time_end`.

**Computation of Delay:**
- If night: delay = night_timeout - dim_time (dim_time is optional)
- Else: delay = day_timeout - dim_time
- Use a `function` node to compute (or a combination of `switch` + change node) and pass the value to the `trigger` or `delay` node.

**Node List (Suggested):**
- events:state, current-state
- switch (for boolean checks), function (for computing delays & night check)
- trigger (in restart mode), delay (for debounce fallback), rbe (optional for repeat suppression)
- call-service (Home Assistant) for light.turn_on / light.turn_off and timer.start/timer.cancel (if using HA timer)

**Optional Features & Missing Info:**
- Lux threshold numeric value (e.g., 20 lux) or explicit rule to ignore lux
- Does `light.shop_light_switch_outlet` support transitions/dimming? If not, dim_time should be ignored.
- Desired brightness value or state when turning light on (default, set brightness)
- Confirm that `timer.shop_light_ignore_timer` exists and is used vs Node-RED debounce logic

**Test Cases:**
1. Motion ON in dark at night -> light turns ON immediately.
2. Motion OFF -> After night_timeout seconds (less any dim_time) light turns off with dim transition.
3. Motion resumes during wait -> timer resets (light stays ON)
4. Light turned off by flow -> debounce prevents immediate retrigger by motion
5. Lux sensor present: if lux >= threshold -> do not turn the light on.

**TESTING:**
- Test 1:
  - Issue 1: Node Type Mismatches - `current-state`, `action` ✅ FIXED
    - **Status:** Fixed (2025-11-20)
    - **Root Cause:** Generated flow JSON without verifying against actual Node-RED node types available in the instance
    - **Investigation:** The node names used were based on assumptions about naming conventions, but actual Node-RED uses the ha-websocket module node types
    - **Findings:**
      - `current_state` → changed to `api-current-state` (correct ha-websocket node type) ✅
      - `action` → changed to `api-call-service` (correct ha-websocket node type) ✅
      - Reference: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/
    - **Resolution Applied:** 
      - Updated both JSON files with corrected node types:
        - `shop_light_motion.json`: Updated node_3 (api-current-state), node_4/7/8 (api-call-service)
        - `bug_zapper_plug.json`: Updated turn_zapper_off and turn_zapper_on nodes (api-call-service)
      - All nodes now use correct ha-websocket module types
      - Ready for manual import into Node-RED
  - Issue 2: Debug Node Purpose - 'Motion OFF (handled by timeout)' ✅ FIXED
    - **Status:** Fixed (2025-11-20)
    - **Purpose:** This is a diagnostic/monitoring node that logs when motion state turns OFF
    - **Function:** 
      - Flow intentionally IGNORES motion OFF events (treats motion OFF as irrelevant)
      - Instead uses a timeout-based relay (output on motion ON, auto-relay off after 5 min)
      - This debug node confirms that OFF events are being properly suppressed
      - Useful during testing/troubleshooting to verify timeout behavior works correctly
    - **Production Use:** Optional node - can be disabled if not needed after testing is complete
    - **Resolution Applied:** Node enabled and included in updated flow for testing telemetry

**IMPROVEMENTS:**
  - IMP01: 
    - Is it possible to handle the Shop Light Motion "De-Bounce" logic with an internal Timer in       NodeRed that DOES NOT require an external Timer in HASS? If so, can you implement that change. Update the Flow Description to reflect this.
  - IMP02: 
    - The existing Night Time is hard-coded to reflect "night" based upon a certain location and time of year. That method is poor. Please update this so it uses the following input_datetime helpers in HomeAssistant:
    - input_datetime.night_time_start
    - input_datetime.night_time_end
  - IMP03: # ✅ ANSWERED
    - The existing functionality allows for a time-prefix and time-suffix for the night_time_start and night_time_end times, how can I define that in such a way as to make it easy to access via Home Assistant and NodeRED? Should I add this as a value defined in some way in the Flow in NodeRED? Define it as an input_datetime in Home Assistant? What options exist for this Configuration option?
    - **Answer:**
      **Decision:** Use `input_number` helpers in Home Assistant for offset minutes
      
      This approach provides the best flexibility and ease of use:
      1. **Create input_number helpers in Home Assistant:**
         - `input_number.night_time_start_offset_minutes` (default: 0, min: -60, max: 60, unit: min)
         - `input_number.night_time_end_offset_minutes` (default: 0, min: -60, max: 60, unit: min)
      2. **In Node-RED function nodes:** Read these helpers' values and add/subtract from the base night_time_start and night_time_end values
      3. **Example usage:** If night_time_start is 17:00 and offset is -15, night effectively starts at 16:45 (15 minutes earlier)
      4. **Advantages:**
         - Single source of truth in Home Assistant
         - Easy to adjust via UI (Automations & Scenes → Helpers → Numbers)
         - No need to edit flows to change offsets
         - Can be shared across multiple flows referencing the same helpers
         - Automations can also reference these offsets
      5. **Implementation:** Add logic in "Check Night Time" function nodes to:
         ```javascript
         offset_start_mins = context.get('night_offset_start') || 0;
         offset_end_mins = context.get('night_offset_end') || 0;
         adjusted_start = night_start - (offset_start_mins * 60);
         adjusted_end = night_end + (offset_end_mins * 60);
         ```
      6. **Production Note:** These helpers can be created manually or via Home Assistant automations/template
  - IMP04: # ✅ ANSWERED
    - The existing functionality allows for a Delay after Motion to turn the Lights off depending on Day or Night, however the node (Wait for Timemout (Day=15m, Night=5m)) does not seem to implement that. Update the Flow to accurately Delay the correct amount of time. This should be clearly labeled so it is easy to set the Day delay and the Night delay. A useful option would be to provide ONE PLACE to define the values in the Flow where they can be Set, then read. In addition, a Global place where they can be set by Area and over-ridden in the Flow would also be useful. This means I could define a Delay of 15m in the Shop area, and then over-ride that for a specific Flow to 30m. A global setting for All Areas would also be useful. Is there a such a way to define Global Vars in NodeRED for this purpose?
    - **Answer:**
      **Decision:** Use `input_number` helpers in Home Assistant for global/area configuration, with optional flow-level overrides
      
      **Three-tier approach for maximum flexibility:**
      
      1. **Global Level** (Home Assistant input_number helpers):
         - `input_number.global_light_off_delay_day_minutes` (default: 15)
         - `input_number.global_light_off_delay_night_minutes` (default: 5)
         - Use case: System-wide defaults for all areas
      
      2. **Area Level** (Home Assistant input_number helpers):
         - `input_number.shop_light_off_delay_day_minutes` (default: 15)
         - `input_number.shop_light_off_delay_night_minutes` (default: 5)
         - Use case: Area-specific overrides (replaces global if set to non-zero)
         - Naming convention: `input_number.[area]_light_off_delay_[day|night]_minutes`
      
      3. **Flow Level** (Node-RED function node):
         - Single dedicated function node: "Get Light-Off Delay"
         - Reads area-level helper → falls back to global → returns milliseconds for delay node
         - Can be re-used across multiple flows
         - Change: Update the "Compute Timeout Duration" function in the flow to query these helpers
      
      **Implementation in Node-RED:**
      ```javascript
      // Get area-specific delay (or use global fallback)
      const area = "shop"; // Set per flow
      const is_night = msg.is_night || false;
      const delay_type = is_night ? "night" : "day";
      
      // Try area-specific first
      const area_helper = `input_number.${area}_light_off_delay_${delay_type}_minutes`;
      let delay_mins = context.global.get(`${area}_delay_${delay_type}`) || null;
      
      // Fall back to global
      if (!delay_mins) {
          const global_helper = `input_number.global_light_off_delay_${delay_type}_minutes`;
          delay_mins = context.global.get(`global_delay_${delay_type}`) || (is_night ? 5 : 15);
      }
      
      msg.delay = delay_mins * 60 * 1000; // Convert minutes to milliseconds
      return msg;
      ```
      
      **Benefits:**
      - Change delays WITHOUT touching Node-RED flows
      - Different areas can have different timeouts
      - Override system defaults per area
      - Easy dashboard integration (users can adjust via Automations UI)
      - Shared across flows and automations
      
      **Current Implementation Status:**
      - ✅ Node-RED delay node with variable timeout is implemented
      - ✅ Function node "Compute Timeout Duration" calculates delay
      - 🔄 Need to add: Querying Home Assistant input_number helpers instead of hardcoded values
      - 🔄 Need to create: input_number helpers in Home Assistant configuration 
  - IMP04: 
    - When building the Flow, can you put all of the Nodes EXCEPT the global-config nodes within a Group? Add this requirement to ALL Flows (update the AGENTS.md) as this makes it easier to move the Flows around. The Group Name should be the same as the Flow name. The following are the styles for the group:
    "style": {
      "stroke": "#2b2b2b",
      "stroke-opacity": "1",
      "fill": "#181818",
      "fill-opacity": "0.5",
      "label": true,
      "label-position": "nw",
      "color": "#cccccc"
    }
  - IMP05: 
    - Can you attempt to set the x/y values of the nodes so they are structed more compactly.
    - The following are how I would resolve where nodes go:
      - First node is at the far left.
      - Second node is directly below the first node, with the x position the same, and the y position is 60 more than the First node.
      - Every node is the same x with y+60 of the prior node.
      - If a node has two branches, the upper branch is placed at the same y as the First node, but the x is incremented 400.
      - Nodes after a branch are structured similar to those after the First node, the go down, not over.
      - If there is more than 1 input on a Node, it should be placed in the next column over after the first input node, so that a later input node can easily be displayed with a wire input and have the wires not cross.
      - The goal is to end up with related nodes "stacked" on top of one another, with branches branching to the next column over, and then being stacked.
  - IMP06: # ✅ ANSWERED
    - the Check Night Time should be a SWITCH node that goes out one output on Day and the other output on Night. That is a much cleaner Flow.
    - **Answer:**
      **Decision:** Replace "Check Night Time" function node with a `switch` node using jsonata expressions
      
      This is cleaner and follows Node-RED best practices (declarative over imperative):
      - Function nodes (imperative): "if time >= start then output 1 else output 2"
      - Switch nodes (declarative): "evaluate condition, route to matching output"
      
      **Conversion:**
      - Replace node type: `function` → `switch`
      - Create two outputs:
        - **Output 1** (Night): condition checks if `current_time >= night_start OR current_time < night_end`
        - **Output 2** (Day): default (no condition, catches all others)
      - Both branches flow to next functional nodes (Turn Light ON)
      - msg.is_night flag set by function before switch can be used in condition
      
      **Alternative Architecture (even cleaner):**
      - Move the night-time calculation to a dedicated function that just sets msg.is_night
      - Use a `switch` node with rule: `msg.is_night == true` (Output 1 = Night) and `msg.is_night == false` (Output 2 = Day)
      - This separates concerns: calculation vs. routing
      
      **Status:** Will be implemented in flow update
      **Implementation Method:** Update shop_light_motion.json node_3 from function to switch node
  - IMP07: # ✅ ANSWERED
    - Add Comments in the Info fieild to facilitate adding Test type Inject Nodes to allow for Testing of the Flow. These comments should indicate what payload would cause this node to branch down a specific branch (for branch nodes) or cause a trigger node to fire (for trigger nodes, like motion nodes).
    - I may later add code to auto-add those Inject nodes, but for now, I may add them manually and once I get some examples of where I place them, I can provide those examples to facilitate developing some instructions for how to add them in the future.
    - For now, simply indicating the expected Input and Output for nodes is adequate.
    - **Answer:**
      **Decision:** Add structured "TEST PAYLOAD" section to each node's info field
      
      **Format for Test Payload Documentation:**
      For **trigger/sensor nodes** (server-state-changed, etc.):
      ```
      **TEST PAYLOAD:**
      - Inject node type: "inject"
      - Payload type: "json"
      - Value: {"new_state": {"state": "on"}}
      - Expected output: Triggers downstream flow
      ```
      
      For **switch/branch nodes**:
      ```
      **TEST PAYLOAD:**
      - Output 1 (branch name): payload.new_state.state == "on"
        - Test: Inject {"new_state": {"state": "on"}}
      - Output 2 (branch name): payload.new_state.state == "off"
        - Test: Inject {"new_state": {"state": "off"}}
      ```
      
      For **function/compute nodes**:
      ```
      **TEST PAYLOAD:**
      - Input: msg with properties {is_night: true|false}
      - Expected output: msg.delay = milliseconds value
      - Test: Inject {is_night: true} or {is_night: false}
      ```
      
      **Implementation Approach:**
      1. Update each node's info field with structured TEST PAYLOAD section
      2. Include minimal inject node JSON that users can copy-paste into Node-RED
      3. Format makes it easy to auto-generate inject nodes later (parse JSON from comments)
      
      **Status:** Will be implemented in shop_light_motion.json node updates
      **Next Steps for User:** After setup, inject test nodes manually to verify flow branches work correctly
  - IMP08: # ✅ ANSWERED
    - The node names are TOO LONG. They should be no longer than 25 chars.
    - Additional details can be indicated in the Info/Description.
    - It makes the Flow too complicated to have such long node-names.
    - **Answer:**
      **Decision:** Implement strict 25-character limit for all node names
      
      **Shortening Strategy:**
      1. Use abbreviations/acronyms where appropriate
      2. Remove unnecessary words (the, a, and, etc.)
      3. Use symbols where applicable (🔴 ✅ ⏱️ etc.)
      4. Move detailed description to Info field
      
      **Examples:**
      - "TIMEOUT DELAY (DAY=15m, NIGHT=5m) - Restarts on Motion" (55 chars) 
        → "⏱️ Timeout Delay" (14 chars) ✅
      - "Check Night Time (from input_datetime)" (39 chars)
        → "Night Time Check" (15 chars) ✅
      - "Compute Timeout Duration (DAY=15m, NIGHT=5m)" (46 chars)
        → "Compute Delay" (13 chars) ✅
      - "DEBOUNCE DELAY (10 seconds) - Internal" (38 chars)
        → "Debounce 10s" (12 chars) ✅
      - "Motion Sensor ON/OFF" (20 chars)
        → "Motion Sensor" (13 chars) ✅ (already OK)
      - "Is Motion ON?" (13 chars)
        → "Motion ON?" (10 chars) ✅ (already short)
      
      **Node Name Consistency:**
      - Use emoji prefix for action nodes (🔴 turn off, 🟢 turn on)
      - Use ⏱️ for timing/delay nodes
      - Use action verbs at start (Check, Compute, Send, etc.)
      - Use short form: "Check X", "Send Y", "Compute Z"
      
      **Status:** Will be implemented in flow updates
      **Updated count:** 8/10 nodes need shortening in shop_light_motion.json
---

### Bug Zapper Plug - Night Control
[Back to Registry](#flow-registry)

**Flow Tab:** Bug Zapper Plug - Night Control
**Category:** Automation
**Status:** Planned (Migrate from HASS Automation)
**Version:** 1.0.0
**Last Modified:** 2025-11-20
**Implementation File:** `flows/automation/bug_zapper_plug.json`

**Purpose:**
On at night only, disabled by daytime or when shop light is on. Keep bug zapper plug `switch.sonoff_10020bac04` ON only at night when the shop light is OFF. Forced OFF during daytime and OFF whenever shop light is ON. Also ensure that it is turned OFF at `night_end` every morning.

**Inputs & Entities:**
- Zapper plug: `switch.sonoff_10020bac04`
- Shop light: `light.shop_light_switch_outlet`
- Night Start / End input_datetime helpers: `input_datetime.night_time_start`, `input_datetime.night_time_end`

**Primary Triggers:**
- `events: state` node for `shop light` (to detect ON state and turn zapper OFF)
- `events: state` node for `zapper plug` (to detect manual ON and force OFF during day)
- `cronplus` or `inject` (time-check) to fire at `night_start` and `night_end` exact times/CRON or to poll dynamically if the times are dynamic.

**Core Logic/Mapping:**
1. If time is `night_end` -> `call-service` to turn zapper OFF
2. If shop light turns ON -> `call-service` to turn zapper OFF
3. If `time` == `night_start` and shop light is OFF -> `call-service` to turn zapper ON
4. If shop light turns OFF while current time is night -> `call-service` to turn zapper ON
5. If zapper gets switched ON during day (manual) -> `call-service` to turn zapper OFF immediately

**Node List (Suggested):**
- events:state (for shop light and zapper)
- cronplus (or inject) and function for dynamic `night` firing
- function for guarding logic (is it night now, is shop light off?), or `switch` + `time-range-switch` to implement conditions declaratively
- call-service (off/on) for `switch.turn_on` and `switch.turn_off`

**Missing Info:**
- Confirm whether zapper should be allowed to be turned on manually at night and persist until triggered off by shop light or `night_end` (current spec allows this, but clarify)
- Confirm the exact `input_datetime` entities in your environment for night_start & night_end and whether they include offsets.

**Test Cases:**
1. At `night_start` with shop light OFF -> zapper turns ON
2. At `night_start` with shop light ON -> zapper remains OFF
3. If shop light turns ON at night -> zapper OFF
4. User manually turns zapper ON during day -> flow detects and forces it OFF
5. At `night_end` -> zapper OFF

**TESTING:**
- Test 1:
  - Issue 1: Node Type Mismatch - `ha-call-service` ✅ FIXED
  - Issue 1: Node Type Mismatch - `action` ✅ FIXED
    - **Status:** Fixed (2025-11-20)
    - **Root Cause:** Same as Shop Light Flow - generated without verifying actual Node-RED node types from ha-websocket module
    - **Investigation:** The `action` node name was based on old documentation, but actual Home Assistant service calls use the `api-call-service` node type
    - **Findings:**
      - `action` → changed to `api-call-service` (correct ha-websocket node type) ✅
      - This node handles `switch.turn_on` and `switch.turn_off` service calls for `switch.sonoff_10020bac04` ✅
      - Reference: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/
    - **Resolution Applied:**
      - Updated both `turn_zapper_off` and `turn_zapper_on` nodes to `api-call-service` type
      - All nodes now use correct ha-websocket module types
      - Ready for manual import into Node-RED
       
  - Issue 2: Debug Node Purpose - 'Zapper Control Action' ✅ FIXED
    - **Status:** Fixed (2025-11-20)
    - **Purpose:** This is an operational logging node that records all zapper ON/OFF actions
    - **Function:**
      - Logs when the flow triggers the zapper plug ON or OFF
      - Records the reason/trigger (night_start, night_end, shop light ON, etc.)
      - Shows the timestamp and payload of each action taken
      - Essential for testing: verify correct actions occur at correct times
      - Useful during production: helps diagnose why zapper is/isn't on when expected
    - **Production Use:** Keep enabled - provides operational telemetry without affecting flow behavior
    - **Resolution Applied:** Node enabled and included in updated flow for operational telemetry

**IMPROVEMENTS:**
  - IMP01: 
    - The existing Night Time is hard-coded to reflect "night" based upon a certain location and time of year. That method is poor. Please update this so it uses the following input_datetime helpers in HomeAssistant:
    - input_datetime.night_time_start
    - input_datetime.night_time_end
  - IMP02: # ✅ ANSWERED (see Shop Light IMP03)
    - As with the Shop Light, IMP03 would be used to resolve the time-prefix and time-suffix for the night_time_start and night_time_end values.
    - **Answer:** Use same approach as Shop Light Flow IMP03 - create `input_number` helpers in Home Assistant:
      - `input_number.bug_zapper_night_start_offset_minutes` (offset before night_time_start)
      - `input_number.bug_zapper_night_end_offset_minutes` (offset after night_time_end)
      - Read these in the night-check function nodes and apply offsets to calculated night times
      - See Shop Light → IMP03 Answer for detailed implementation approach
---

## Flow Categories

### Automation
Flows that automate home devices and scenarios based on conditions and triggers.

### Notification
Flows that handle alerts, messages, and notifications to various endpoints.

### Monitoring
Flows that track and report system state, status, and metrics.

### Integration
Flows that connect external services or systems with Home Assistant.

### Data Processing
Flows that transform, aggregate, or process data from various sources.

---

## Development Guidelines

When adding a new flow to this registry:

1. **Assign a Category**: Choose from existing categories or propose new ones
2. **Version Numbering**: Use semantic versioning (MAJOR.MINOR.PATCH)
3. **Status Tracking**: Update status as flow progresses through development
4. **File Organization**: Store JSON exports in `flows/[category]/` subdirectories
5. **Documentation**: Include comments and descriptions within the flow itself

See `NODERED-PROJECT-HISTORY.md` for architectural decisions and design patterns.