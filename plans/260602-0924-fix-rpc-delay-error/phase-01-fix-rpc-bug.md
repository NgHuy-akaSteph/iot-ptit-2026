# Phase 1: BFF Backend Fix

## Context Links
- **Report**: [Debugger Report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/debugger-260602-0924-fix-rpc-delay-error.md)
- **Source**: [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)
- **Source**: [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)
- **Source**: [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java)

## Overview
- **Priority**: CRITICAL
- **Current Status**: IN_PROGRESS
- **Description**: Modify the Spring Boot BFF backend to correctly handle empty response bodies from ThingsBoard's `/api/plugins/rpc/oneway/{deviceId}` lightweight RPC endpoint.

## Key Insights
- Standard lightweight one-way RPC calls in ThingsBoard return HTTP 200 OK with an **empty response body**.
- Spring's `bodyToMono(String.class)` yields `Mono.empty()` on empty body, skipping downstream mapping operations and causing RpcController to fallback to 400 Bad Request via `defaultIfEmpty`.
- Adding `defaultIfEmpty("{\"status\":\"success\"}")` cleanly addresses this.

## Requirements
- BFF should return HTTP 200 OK with JSON `{"status":"success"}` when ThingsBoard successfully executes one-way RPC.
- BFF should correctly update DB `command_log` table status to `SUCCESS` upon successful delivery.

## Related Code Files
- [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)

## Implementation Steps
1. Add `.defaultIfEmpty("{\"status\":\"success\"}")` to `sendRpcCommand` in `ThingsboardClient.java`.
2. Compile and run server to verify there are no compilation errors.

## Todo List
- [ ] Modify `ThingsboardClient.java`
- [ ] Verify server compiles successfully

## Success Criteria
- Successful compilation.
- Correct handling of empty bodies.

## Risk Assessment
- Low risk. Only affects one-way RPC commands which previously crashed the reactive chain anyway.
