# Phase 2: Backend Implementation

## Context Links
- [TelemetryService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/TelemetryService.java)
- [TelemetryController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/TelemetryController.java)
- [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)

## Overview
- **Priority**: HIGH
- **Current Status**: PENDING
- **Description**: Update telemetry saving to include `mistOn` and `waterLow`. Modify `getLatestTelemetry` to fetch from ThingsBoard, save new telemetry to database, and fall back to local database. Handle alert resolution logic and threshold logging.

## Key Insights
- We need to extract the exact timestamp from the ThingsBoard payload so we can avoid duplicate data points in the local DB.
- Alert logs must follow a state machine pattern to avoid logging redundant alerts on every polling interval.

## Requirements
- Support `mist_on` and `water_low` in POST `/telemetry/webhook`.
- Modify `getLatestTelemetry` endpoint to fetch from ThingsBoard, check for duplicate timestamp, save new data, and return format expected by client.
- Trigger `ThresholdHistory` creation on successful `setThresholds` RPC command.
- Expose endpoints to query alert logs and threshold history.

## Related Code Files
- [MODIFY] [TelemetryService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/TelemetryService.java)
- [MODIFY] [TelemetryController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/TelemetryController.java)
- [MODIFY] [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)

## Implementation Steps
1. Update `TelemetryService` signature and implementation of `saveTelemetry` to include `mistOn` and `waterLow`.
2. Implement Alert monitoring inside `TelemetryService` using a state machine to resolve and create logs in `alert_log`.
3. Update `TelemetryController.getLatestTelemetry` to fetch from ThingsBoard first.
4. Modify `RpcService` to inject `ThresholdHistoryRepository` and save thresholds when `setThresholds` commands complete with status `SUCCESS`.
5. Add REST endpoints for fetching active alerts, alert history, and threshold history.

## Todo List
- [ ] Implement `TelemetryService` updates (parameters, alert checks)
- [ ] Update `TelemetryController.getLatestTelemetry` to ALWAYS fetch from ThingsBoard and save
- [ ] Implement `RpcService` save to `ThresholdHistory`
- [ ] Create REST endpoints for alerts and threshold history
- [ ] Run backend compile checks

## Success Criteria
- Backend compiles with Gradle without errors.
- Calling `/latest` retrieves telemetry from ThingsBoard, saves to local DB, and evaluates alerts.
- RPC threshold updates log to database.

## Risk Assessment
- *Risk*: ThingsBoard response structure parsing errors.
- *Mitigation*: Fall back safely to DB latest values on any API exception.
