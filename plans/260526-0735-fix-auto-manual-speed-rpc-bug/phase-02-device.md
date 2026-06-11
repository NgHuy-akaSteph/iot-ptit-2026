# Phase 02: ESP32 Firmware Robust RPC Param Parsing Fixes

## Context Links
- [debugger report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/debugger-260526-0735-fix-auto-manual-speed-rpc-bug.md)
- [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/plan.md)

## Overview
- **Priority**: HIGH
- **Current Status**: SKIPPED
- **Description**: Modify `device/src/main.cpp` to correctly check the ArduinoJson payload type and parse the `setFan` RPC parameter whether it's serialized as an integer or string.

## Key Insights
- ArduinoJson `as<String>()` returns empty when casting integer nodes. Using `is<int>()` and `as<int>()` ensures compatibility with numeric payloads.

## Requirements
- Support setting fan level (1: Thấp, 2: Trung, 3: Cao) from Flutter through BFF / ThingsBoard RPC.
- Maintain fallback checks to prevent null pointer exceptions or parsing resets.

## Architecture
```
ThingsBoard MQTT Broker -> ESP32 MQTT Subscription (v1/devices/me/rpc/request/+)
  -> onMqttMessage Callback -> ArduinoJson parsing -> fanLevel update -> PWM/Relay control
```

## Related Code Files
- [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Implementation Steps
1. Navigate to `onMqttMessage` in `device/src/main.cpp`.
2. Replace `setFan` parsing block to inspect if the node is an integer, string, or char pointer.
3. Update `fanLevel` only on valid non-negative values.

## Todo List
- [ ] Modify `device/src/main.cpp` with robust ArduinoJson parsing logic.
- [ ] Compile device code to verify syntax (if toolchain available, or manual validation).

## Success Criteria
- Device compiles cleanly.
- Changing speed on the client updates the ESP32 fan PWM and triggers the buzzer alarm successfully.

## Risk Assessment
- *Risk*: Invalid parameters resetting speed to 0.
- *Mitigation*: Ensure validation checks `level >= 0` before assigning it to the global state.

## Security Considerations
- RPC subscriptions are secure via MQTT authentication token.

## Next Steps
- Move to Phase 03 (Verification).
