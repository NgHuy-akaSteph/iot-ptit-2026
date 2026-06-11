# Phase 1: ESP32 Firmware Implementation

## Context Links
- **Implementation Plan**: [implementation_plan.md](file:///C:/Users/ACER/.gemini/antigravity-ide/brain/1a211fa5-e3a6-4b1d-b9f9-1e9f10111819/implementation_plan.md)
- **Main Device Code**: [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Overview
- **Priority**: HIGH
- **Current Status**: DONE
- **Description**: Add misting module relay output on GPIO 33 and water level sensor input on GPIO 2. Make misting temperature and humidity thresholds dynamic and saved in NVS Preferences.

## Requirements
- Pin assignments: `MIST_RELAY_PIN = 33`, `WATER_SWITCH_PIN = 2`.
- Misting thresholds: `tempHigh` (default 35.0) and `humLow` (default 60.0) read/written using `Preferences` ("thresholds").
- Auto mode logic: Turn misting on if `temperature > tempHigh` AND `humidity < humLow` (and normal water).
- MQTT:
  - Telemetry: Send `mist_on` and `water_low`.
  - RPC: Update `setThresholds` to accept and save `tempHigh` and `humLow`, and `getThresholds` to return them.
  - Manual control: Ensure `setMist` RPC toggles misting when in manual mode.

## Related Code Files
- [MODIFY] [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Implementation Steps
1. Add `volatile float tempHigh` and `volatile float humLow` globals.
2. Load values from Preferences namespace `"thresholds"` in `setup()`.
3. Read `tempHigh` and `humLow` under mutex protection in `controlTask()` and update condition.
4. Support parsing and saving of `tempHigh`/`humLow` in `setThresholds` RPC handler in `onMqttMessage()`.
5. Support retrieving `tempHigh`/`humLow` in `getThresholds` RPC handler in `onMqttMessage()`.
6. Ensure `setMist` RPC handler is fully functional.
7. Verify compilation success using PlatformIO.

## Todo List
- [x] Add `tempHigh` and `humLow` globals and load them from Preferences in `setup()`
- [x] Update `controlTask()` to use dynamic thresholds under mutex
- [x] Update `setThresholds` and `getThresholds` RPC handlers to handle `tempHigh` and `humLow`
- [x] Verify compilation success using PlatformIO

## Success Criteria
- Code compiles.
- Thresholds are successfully saved, restored, and queryable.
- Misting activates according to dynamic thresholds.
- `setMist` toggles relay when `autoMode` is false.
