# Phase 01: Backend Spring BFF One-way RPC and Error Propagation

## Context Links
- [debugger report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/debugger-260526-0815-fix-rpc-delay-and-error.md)
- [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0815-fix-rpc-delay-and-error/plan.md)

## Overview
- **Priority**: HIGH
- **Current Status**: COMPLETE
- **Description**: Upgrade the Spring Boot backend to use one-way RPC calls to Thingsboard, propagate error responses with non-200 HTTP status codes, and offload blocking database operations to boundedElastic thread pools.

## Key Insights
- **One-way vs Two-way**: The Flutter client doesn't need to wait for a hardware response before updating the switch state locally. Switching to `/api/plugins/rpc/oneway/{deviceId}` eliminates the 10-second blocking timeout delay when devices are slow or offline.
- **Error Propagation**: Return HTTP 500 (or HTTP 400) if the proxy call to ThingsBoard fails, ensuring the Flutter client's Dio instance throws an error and displays the red error SnackBar.
- **Blocking Event Loop**: Wrap the database read in `TelemetryController.getLatestTelemetry` inside a `Mono.fromCallable` scheduled on `Schedulers.boundedElastic()` to keep the main reactive threads free.

## Requirements
- Instantaneous HTTP responses (less than 100ms) for auto-mode toggling and speed adjustments.
- Real HTTP 500 returned to Flutter client upon RPC failure.
- Zero Netty EventLoop thread blocking.

## Related Code Files
- [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)
- [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java)
- [TelemetryController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/TelemetryController.java)

## Implementation Steps
1. Modify `ThingsboardClient.java` to call `/api/plugins/rpc/oneway/{deviceId}` instead of `/api/plugins/rpc/twoway/{deviceId}` in `sendRpcCommand()`.
2. Modify `RpcController.java` to inspect the response of `sendRpcCommand()`. If it contains `"status":"error"` or `"error"`, return `ResponseEntity.status(500).body(response)` instead of `ResponseEntity.ok(...)`.
3. Modify `TelemetryController.java` in `getLatestTelemetry()` to fetch from local database using `Mono.fromCallable(() -> telemetryService.getLatestTelemetry(deviceId)).subscribeOn(Schedulers.boundedElastic())` instead of the eager `Mono.justOrEmpty(...)`.

## Todo List
- [ ] Update ThingsboardClient for one-way RPC.
- [ ] Update RpcController for error HTTP code propagation.
- [ ] Update TelemetryController for EventLoop thread safety.
- [ ] Compile and verify tests pass.

## Success Criteria
- Backend compiles and tests pass.
- Calling `/api/devices/{deviceId}/rpc` is extremely fast.
- Failed RPC requests correctly return HTTP 500.
