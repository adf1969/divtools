# Node-RED Flow Tests

This directory contains test flows and test data for validating Node-RED automation flows.

## Directory Structure

### flow_tests/
Contains Node-RED flow JSON files specifically designed for testing.

---

## Testing Strategy

### Test Types

#### 1. Unit Tests (Individual Flow Testing)
Test individual flows with controlled inputs and verify expected outputs.

**Approach:**
- Create test flow with `inject` node providing known input
- Include `debug` nodes to capture output
- Use `switch` nodes to validate conditions
- Create separate test tab in Node-RED

**File naming:** `test_[flow_name].json` (e.g., `test_motion_detection.json`)

---

#### 2. Integration Tests
Test flows that interact with Home Assistant entities and services.

**Approach:**
- Use test Home Assistant entities (create test entities in HASS)
- Create flows with mock service responses
- Verify correct HASS service calls are made
- Test with expected and unexpected state values

**Prerequisites:**
- Access to test Home Assistant instance
- Test entities created in HASS config
- Understanding of entity IDs used in flows

---

#### 3. End-to-End Tests
Test complete flow execution from trigger to result.

**Approach:**
- Set up test environment mirroring production
- Use actual HASS entities in test instance
- Monitor flow execution and verify results
- Check logs for errors or warnings

---

## Test Data

### test_data.json
Contains sample payloads and test data used by test flows.

**Examples:**
- Mock HASS entity state changes
- Sample sensor readings
- API response samples
- Message payloads

### Creating Test Data
1. Export actual data from HASS or flows
2. Sanitize sensitive information
3. Document what each test case represents
4. Include comments explaining expected behavior

---

## Running Tests

### Manual Testing in Node-RED

1. **Import test flow**: Open Node-RED → Import → select test JSON
2. **Enable debug**: Click debug node to see output panel
3. **Trigger flow**: Click inject node to start flow
4. **Verify output**: Check debug panel for expected results
5. **Check logs**: Monitor Node-RED logs for errors

### Test Checklist

For each flow test, verify:
- [ ] Flow imports without errors
- [ ] All node types are available
- [ ] HASS entity IDs are correct
- [ ] Service calls execute successfully
- [ ] Output matches expected format
- [ ] Error handling works correctly
- [ ] Flow completes without errors
- [ ] Performance is acceptable (no timeouts)

---

## Test Flow Template

When creating new test flows:

```json
{
  "id": "test_flow_[name]",
  "type": "tab",
  "label": "Test: [Flow Name]",
  "disabled": false,
  "info": "Test flow for [describing what is being tested]\n\nExpected behavior:\n- [Expected outcome 1]\n- [Expected outcome 2]\n\nTest data: See test_data.json",
  "env": [],
  "nodes": [
    {
      "id": "[node_id]",
      "type": "inject",
      "label": "Test Input",
      "topic": "",
      "payload": "{test_data}",
      "payloadType": "json",
      "repeat": "",
      "crontab": "",
      "once": false,
      "onceDelay": 0.1,
      "x": 100,
      "y": 100,
      "wires": [[]]
    },
    {
      "id": "[debug_id]",
      "type": "debug",
      "name": "Output",
      "active": true,
      "tosidebar": true,
      "console": false,
      "tostatus": false,
      "complete": "payload",
      "x": 400,
      "y": 100,
      "wires": []
    }
  ],
  "links": [],
  "groups": [],
  "configs": []
}
```

---

## Best Practices

### Test Flow Organization
- Keep test flows separate from production flows
- Use descriptive tab names (e.g., "Test: Motion Detection")
- Include test purpose in flow properties
- Clean up test nodes before moving to production

### Test Data Management
- Version test data with flows
- Document what each test case represents
- Include comments in test data JSON
- Keep sensitive data separate (use environment variables)

### Debugging
- Use debug nodes liberally in test flows
- Enable console logging for detailed output
- Check Node-RED logs for system-level errors
- Use function nodes to validate intermediate values

### Documentation
- Comment test flows explaining what they test
- Document expected inputs and outputs
- List any Home Assistant entity dependencies
- Note any mock services or test data used

---

## Common Test Patterns

### Pattern 1: State Change Testing
Test flow behavior when HASS entity state changes.

```
[inject: mock state change] → [state node: filter] → [debug: verify result]
```

### Pattern 2: Service Call Validation
Test that correct HASS service is called with correct parameters.

```
[inject: trigger] → [flow logic] → [call service] → [debug: verify parameters]
```

### Pattern 3: Data Transformation
Test data processing and transformation logic.

```
[inject: input data] → [function: transform] → [debug: verify output]
```

### Pattern 4: Timing and Delays
Test flows with time-based conditions and delays.

```
[time trigger] → [condition: time check] → [action] → [debug: verify timing]
```

---

## Troubleshooting Tests

| Issue | Solution |
|-------|----------|
| Flow not triggering | Check inject node configuration, verify trigger conditions |
| No debug output | Enable debug node, check node wiring, verify payload format |
| HASS service fails | Verify entity ID exists, check service name spelling, confirm parameters |
| Unexpected output | Add more debug nodes, check data transformations, verify conditions |
| Performance issues | Check for infinite loops, excessive polling, missing time delays |

---

## References

- **AGENTS.md** - Development guidelines and testing recommendations
- **FLOW-LIST.md** - Master registry with flow status
- **Node-RED Docs**: https://nodered.org/docs/user-guide/
- **Home Assistant Testing**: https://www.home-assistant.io/docs/