# Phase 4: Telemetry Webhook & RPC Proxy Endpoints

## Context Links
- Main Plan: [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/plan.md)

## Overview
- **Priority**: HIGH
- **Status**: PENDING
- **Description**: Add REST API endpoints in BFF for: Telemetry Push (webhook from ThingsBoard), Telemetry Fetch (historical/latest), and RPC sending (with execution logging).

## Key Insights
- ThingsBoard rules can push telemetry. Our `/api/telemetry/webhook` should be configured with simple token/key authentication (or permitAll if secured via server IP whitelist).
- RPC commands are saved before making downstream ThingsBoard REST calls, and updated once response is received.

## Requirements
- Webhook endpoint saving incoming JSON telemetry into the database.
- Get Telemetry endpoint mapping list of database entries.
- Rpc command endpoint doing a 2-way call to `https://thingsboard.cloud/api/plugins/rpc/twoway/{deviceId}`.

## Related Code Files
- [NEW] [TelemetryController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/TelemetryController.java)
- [NEW] [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java)
- [NEW] [TelemetryService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/TelemetryService.java)
- [NEW] [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)

## Implementation Steps
1. Create `TelemetryService` containing functions `saveTelemetry`, `getLatestTelemetry`, and `getHistory`.
2. Create `TelemetryController` presenting:
   - `POST /api/telemetry/webhook`: endpoint for ThingsBoard rules to post telemetries.
   - `GET /api/devices/{deviceId}/telemetry/latest`
   - `GET /api/devices/{deviceId}/telemetry/history`
3. Create `RpcService` containing `sendRpcCommand` saving to `CommandLog` and calling `ThingsboardClient.sendRpcCommand`.
4. Create `RpcController` presenting `POST /api/devices/{deviceId}/rpc`.

## Todo List
- [ ] Implement `TelemetryService` operations
- [ ] Implement Webhook and Get endpoints in `TelemetryController`
- [ ] Implement `RpcService` database logging & WebClient delegation
- [ ] Implement `RpcController`

## Success Criteria
- Telemetry pushes successfully write to `telemetry_data`.
- Sending RPC records a log entry in `command_log` and correctly forwards the command.
