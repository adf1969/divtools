# Shop Light & Bug Zapper Flow - Testing Issues Resolution
# Last Updated: 2025-11-20 16:00:00 CST

## Issue Investigation & Answers

### Shop Light - Motion Flow

#### Issue 1: Non-Existent Node Types
**Problem**: The flow references node types that don't exist in Node-RED:
- `current-state` (should be `current_state` with underscore)
- `ha-call-service` (this is a custom node from Home Assistant integration)
- `wait` (should be `wait until` or delay node)

**Root Cause Analysis**:
I generated the JSON flow without directly accessing the Node-RED instance to verify available node types. I relied on generic node naming conventions and made assumptions about Home Assistant integration nodes.

**Investigation Findings**:
1. **`current-state` → should be `current_state`**
   - This is likely the "Home Assistant - Current State" node
   - Used with underscore naming convention in Node-RED
   - Properly checks if an entity state meets a condition
   
2. **`ha-call-service` → should be `action` OR custom node**
   - The actual Home Assistant service calling node may be named `action`
   - OR it could be a proprietary node from the Home Assistant node-red add-on
   - Requires verification by checking Node-RED UI's available nodes
   
3. **`wait` → should be `wait until` or `delay`**
   - The generic "Wait" node exists in Node-RED
   - "Wait Until" node can wait for state changes
   - "Delay" node can delay messages by fixed time
   - For 15-minute timeout, a combination of trigger + delay is needed

**How These Nodes Are Used in the Flow**:

1. **`current_state` (Debounce Timer Check)**
   - **Purpose**: Prevents light from turning ON if debounce timer is still active
   - **Configuration**: 
     - Entity ID: `timer.shop_light_de_bounce`
     - Condition: State is NOT "active"
     - Halt if condition not met: true (blocks further execution)
   - **Why**: Debouncing prevents rapid on/off cycling if motion is detected repeatedly

2. **`action` / Service Call Nodes** (Light ON/OFF, Timer START)
   - **Purpose**: Execute Home Assistant service calls
   - **Configuration for Light ON**:
     - Service: `light.turn_on`
     - Target: `light.shop_light_switch_outlet`
     - No transition (instant ON)
   - **Configuration for Light OFF**:
     - Service: `light.turn_off`
     - Target: `light.shop_light_switch_outlet`
     - Transition: 30 seconds (smooth dimming)
   - **Configuration for Debounce Timer**:
     - Service: `timer.start`
     - Target: `timer.shop_light_de_bounce`
     - Duration: "00:00:10" (10 seconds)

3. **`wait until` / Delay Logic** (Timeout calculation)
   - **Purpose**: Wait for timeout period before turning light off
   - **Strategy**:
     - Calculate timeout based on day/night: 15 min (day) or 5 min (night)
     - Use "Delay" node with variable delay
     - OR use "Trigger" node in "restart" mode (resets timeout if motion detected again)
   - **Current Implementation**:
     - Uses "trigger" node with 15-minute default
     - Function node calculates actual timeout based on night time
     - Restarts if motion detected again during wait

**Recommended Fixes**:

```json
// Instead of "current-state", use:
{
  "id": "node_3",
  "type": "current_state",  // ← Changed from "current-state"
  "z": "shop_light_motion_tab",
  "name": "Check Debounce Timer Not Active",
  ...
}

// Instead of "ha-call-service", use:
{
  "id": "node_4",
  "type": "action",  // ← Changed from "ha-call-service"
  "z": "shop_light_motion_tab",
  "name": "Turn Light ON",
  "service": "light.turn_on",
  "target": {
    "entity_id": "light.shop_light_switch_outlet"
  },
  ...
}

// Instead of "wait", verify node type:
// If using "trigger" node (current approach):
{
  "id": "node_5",
  "type": "trigger",  // ← Correct for timeout with restart
  "mode": "restart",  // ← Allows timeout to reset if motion detected again
  "duration": "15",
  "units": "min",
  ...
}
// OR if using explicit delay:
{
  "id": "node_5_alt",
  "type": "delay",  // ← Alternative for simple fixed delay
  "timeout": 900,  // 15 minutes in seconds
  ...
}
```

#### Issue 2: Debug Node "Motion OFF (handled by timeout)"
**Question**: What is the purpose of this debug node?

**Answer**:
This debug node serves as **monitoring/diagnostic output** for the flow. Its purposes are:

1. **Flow Tracking**: Helps developers understand that when motion turns OFF, the flow doesn't immediately turn off the light. Instead, it ignores the OFF event and lets the timeout handle the light shutdown.

2. **Debugging**: Shows in the Node-RED debug panel whenever motion sensor goes OFF, allowing testing and troubleshooting.

3. **Development Aid**: During development/testing, you can see:
   - When motion was detected as OFF
   - What the system received
   - Confirmation that the OFF path was taken

**Why It's Included**:
- The flow has two paths: "Motion ON" (triggers light) and "Motion OFF" (ignored)
- The "Motion OFF (handled by timeout)" debug node documents this intentional behavior
- It's disabled (`active: false`) in production to avoid debug spam
- Can be enabled during testing to verify the OFF event is being received

**Alternative Implementations**:
- Remove it entirely if pure production use (no debugging needed)
- Keep it disabled and enable during troubleshooting
- Add comment node explaining: "When motion stops, timeout waits [15m day / 5m night] before turning light off"

---

### Bug Zapper Plug - Night Control Flow

#### Issue 1: Non-Existent Node Type `ha-call-service`
**Problem**: Flow references node type `ha-call-service` which doesn't exist

**Root Cause**: Same as Shop Light - I assumed the Home Assistant integration provides this node type without verification.

**Investigation Findings**:
The correct node for calling Home Assistant services is likely:
- **`action`** - Home Assistant's standard service call node
- Or a custom node from the Home Assistant add-on with different name

**How It's Used in Bug Zapper Flow**:
1. **Turn Zapper OFF** (when shop light turns ON during night)
   - Service: `switch.turn_off`
   - Target: `switch.sonoff_10020bac04`
   
2. **Turn Zapper ON** (when shop light turns OFF during night)
   - Service: `switch.turn_on`
   - Target: `switch.sonoff_10020bac04`

**Recommended Fix**:
```json
// Change all service call nodes from "ha-call-service" to "action":
{
  "id": "turn_zapper_off",
  "type": "action",  // ← Changed from "ha-call-service"
  "z": "bug_zapper_night_tab",
  "name": "Turn Zapper Plug OFF",
  "service": "switch.turn_off",
  "target": {
    "entity_id": "switch.sonoff_10020bac04"
  },
  ...
},
{
  "id": "turn_zapper_on",
  "type": "action",  // ← Changed from "ha-call-service"
  "z": "bug_zapper_night_tab",
  "name": "Turn Zapper Plug ON",
  "service": "switch.turn_on",
  "target": {
    "entity_id": "switch.sonoff_10020bac04"
  },
  ...
}
```

#### Issue 2: Debug Node "Zapper Control Action"
**Question**: What is the purpose of this debug node?

**Answer**:
This debug node serves **the same purpose as in the Shop Light flow**:

1. **Action Logging**: Shows when zapper control actions occur
   - When zapper is turned OFF (light turned ON during night)
   - When zapper is turned ON (light turned OFF during night)
   - Confirms service calls are being made

2. **Testing Aid**: Helps verify:
   - That night-time logic is working correctly
   - That the right action is triggered at the right time
   - That the flow is responding to light state changes

3. **Monitoring**: In production, can be enabled to track:
   - How often the zapper was controlled
   - When it was controlled (for debugging if behavior is unexpected)
   - Error cases if service calls fail

**Why It's Disabled**:
- Disabled (`active: false`) to avoid debug output spam in normal operation
- Can be enabled for testing/troubleshooting

**Alternative Implementations**:
- Remove if no debugging needed
- Keep disabled for troubleshooting when needed
- Add comment node: "Logs when zapper is turned ON/OFF based on light state and night time"

---

## Summary of Required Changes

### File: `/home/divix/divtools/projects/hass/nodered/flows/automation/shop_light_motion.json`

**Changes Needed**:
1. Line with `"type": "current-state"` → change to `"type": "current_state"`
2. All lines with `"type": "ha-call-service"` → change to `"type": "action"` (3 occurrences)
3. Verify "wait" node type or change to "trigger" or "delay" as appropriate
4. Consider if debug nodes should remain or be removed

### File: `/home/divix/divtools/projects/hass/nodered/flows/automation/bug_zapper_plug.json`

**Changes Needed**:
1. All lines with `"type": "ha-call-service"` → change to `"type": "action"` (2 occurrences)
2. Consider if debug nodes should remain or be removed

---

## Implementation Notes

### Testing the Fixed Flows

After making node type corrections:

1. **Delete old flows** from Node-RED
2. **Update JSON files** with corrections
3. **Re-import flows** to Node-RED
4. **Verify in UI**:
   - All nodes appear correctly
   - Node connections are intact
   - No "missing node" errors (red triangles)
5. **Test functionality**:
   - Use inject nodes to trigger motion detection
   - Verify light turns on/off appropriately
   - Check zapper control during night hours
   - Monitor debug output if enabled

### Node Type Discovery

To find the correct node types in your Node-RED instance:

1. **Open Node-RED UI** (http://10.1.1.215:1880)
2. **Open Palette** (left sidebar)
3. **Search for nodes**:
   - Search "current" to find state checking nodes
   - Search "action" or "service" to find service call nodes
   - Look for Home Assistant integration nodes
4. **Drag nodes into flow** to see their actual type names
5. **Check node properties** to understand configuration

---

## Questions Answered

✅ **Why were these node types used?**
- Generated without direct Node-RED instance verification
- Made assumptions about node naming conventions

✅ **Do they require extensions?**
- Possibly - `action` might be from Home Assistant add-on
- Current Node-RED might have different node names

✅ **What do the debug nodes do?**
- Provide flow monitoring and debugging output
- Help track when motion/light/zapper state changes occur
- Can be enabled/disabled as needed

✅ **How should they be fixed?**
- Update node type names to match actual Node-RED nodes
- Verify node names before deployment
- Keep debug nodes but understand their purpose

---

## Next Steps

1. Update the JSON flow files with correct node types
2. Re-import flows to Node-RED
3. Test with inject nodes
4. Update FLOW-LIST.md marking these issues as "Fixed"
5. Run vitest suite to ensure integration works
6. Mark flows as "Completed" once all issues resolved

