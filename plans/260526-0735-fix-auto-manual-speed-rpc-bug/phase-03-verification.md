# Phase 03: Verification and End-to-End Tracing

## Context Links
- [debugger report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/debugger-260526-0735-fix-auto-manual-speed-rpc-bug.md)
- [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/plan.md)

## Overview
- **Priority**: MEDIUM
- **Current Status**: COMPLETE
- **Description**: Validate both the Spring Boot BFF build and firmware compilation, and trace execution to confirm that both auto-mode switching and manual speed control work without error.

## Related Code Files
- [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)
- [main.cpp](file:///h:/SideProjects/iot-ptit-2026/device/src/main.cpp)

## Todo List
- [ ] Compile Spring Boot backend using Gradle.
- [ ] Review implementation to ensure zero EventLoop blocking.
- [ ] Confirm database logging of commands in Neon PG.

## Success Criteria
- Gradle compile returns SUCCESS.
- BFF successfully processes `setAutoMode` and `setFan` RPC commands from Flutter.
- Commands are recorded as `SUCCESS` in the database.
- ESP32 hardware correctly responds to auto mode changes and manual fan level selections.
