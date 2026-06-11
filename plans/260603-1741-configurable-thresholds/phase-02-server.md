# Phase 2: BFF Server Bridge Endpoints

## Context Links
- **Researcher Report**: [researcher-260603-1741-configurable-thresholds.md](file:///h:/SideProjects/iot-ptit-2026/plans/reports/researcher-260603-1741-configurable-thresholds.md)
- **ThingsboardClient**: [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)
- **RpcService**: [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)
- **RpcController**: [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java)

## Overview
- **Priority**: HIGH
- **Current Status**: TODO
- **Description**: Extend the backend server with generic two-way RPC execution support and add custom endpoints for thresholds retrieval (`GET`) and configuration (`POST`).

## Key Insights
- **Synchronous Two-Way RPC**: ThingsBoard supports synchronous RPC commands via the `/api/plugins/rpc/twoway/{deviceId}` endpoint. This endpoint holds the HTTP request open until the device publishes its reply or the request times out.

## Requirements
- Endpoint `POST /api/devices/{deviceId}/thresholds` forwards config to device using one-way RPC `setThresholds`.
- Endpoint `GET /api/devices/{deviceId}/thresholds` queries device using two-way RPC `getThresholds` and forwards response.
- Access to both endpoints must be secured by Spring Security (using the existing `BffJwtFilter`).

## Architecture
- Client (Flutter) -> Spring Boot Controller -> RpcService -> ThingsboardClient -> ThingsBoard REST -> Device via MQTT.

## Related Code Files
- [MODIFY] [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)
- [MODIFY] [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)
- [MODIFY] [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java)

## Implementation Steps
1. In `ThingsboardClient.java`, implement `sendTwoWayRpcCommand(...)` pointing to `/api/plugins/rpc/twoway/{deviceId}`.
2. In `RpcService.java`, implement `sendTwoWayRpcCommand(...)` that writes a command log with `PENDING` status, calls the two-way RPC client, updates the log status to `SUCCESS` or `FAILED` based on the response, and returns the response.
3. In `RpcController.java`, implement the `POST /api/devices/{deviceId}/thresholds` endpoint. Extract JWT auth context credentials (TB token) and username, and call `rpcService.sendRpcCommand(...)` with method `"setThresholds"`.
4. In `RpcController.java`, implement the `GET /api/devices/{deviceId}/thresholds` endpoint. Extract JWT credentials and call `rpcService.sendTwoWayRpcCommand(...)` with method `"getThresholds"` and empty parameter Map.
5. Compile and run the Spring Boot project.

## Todo List
- [ ] Implement two-way RPC method in `ThingsboardClient.java`.
- [ ] Implement two-way RPC logging method in `RpcService.java`.
- [ ] Create `POST` thresholds endpoint in `RpcController.java`.
- [ ] Create `GET` thresholds endpoint in `RpcController.java`.
- [ ] Verify server compiles successfully.

## Success Criteria
- The server compiles and runs.
- APIs return correct responses.
- Accessing endpoints without Authorization headers returns HTTP 401 Unauthorized.
