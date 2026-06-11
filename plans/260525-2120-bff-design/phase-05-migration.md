# Phase 5: Flutter Client Migration & Verification

## Context Links
- Main Plan: [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/plan.md)

## Overview
- **Priority**: MEDIUM
- **Status**: PENDING
- **Description**: Migrate Flutter app's services (`AuthService`, `ThingsBoardService`, `WebSocketService`) to use BFF instead of calling ThingsBoard directly. Run automated/manual validation.

## Key Insights
- Flutter client should configure its base API URL to point to Spring Boot BFF (e.g. `http://localhost:8080/api` or local network IP).
- Replace direct ThingsBoard REST paths with BFF endpoints.

## Requirements
- Flutter authenticates with BFF and saves the BFF token.
- Flutter telemetry calls fetch from BFF.
- Flutter RPC commands send through BFF.
- Websocket proxy or polling implemented via BFF.

## Related Code Files
- [MODIFY] [auth_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/auth_service.dart)
- [MODIFY] [thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart)
- [MODIFY] [websocket_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/websocket_service.dart)

## Implementation Steps
1. Change `AuthService` Base URL to `http://<BFF_IP>:8080/api`.
2. Update login endpoint to `/auth/login`.
3. Update `ThingsBoardService` methods to hit `/devices/{deviceId}/telemetry/latest`, `/devices/{deviceId}/telemetry/history` and `/devices/{deviceId}/rpc`.
4. Modify `WebSocketService` or map telemetry fetch to REST API calls/polling to simplify websocket proxying.

## Todo List
- [ ] Update `AuthService` baseUrl and login path
- [ ] Update `ThingsBoardService` to call BFF endpoints
- [ ] Connect/Verify Flutter app functionality with running BFF instance

## Success Criteria
- Flutter logs in successfully to BFF.
- Dashboard shows real-time/latest telemetry pulled from BFF.
- Radial gauges and switches successfully control ESP32 through BFF RPC logs.
