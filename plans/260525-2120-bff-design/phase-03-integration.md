# Phase 3: BFF Authentication and ThingsBoard Integration

## Context Links
- Main Plan: [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/plan.md)
- Design details: [phase-01-design.md](file:///h:/SideProjects/iot-ptit-2026/plans/260525-2120-bff-design/phase-01-design.md)

## Overview
- **Priority**: HIGH
- **Status**: PENDING
- **Description**: Configure Spring Security to use JWT Resource Server. Create ThingsBoard WebClient service for relaying login requests and downstream APIs.

## Key Insights
- Generate Spring Security JWT on successful Thingsboard auth, storing Thingsboard JWT in claims.
- Create a `ThingsboardClient` utility wrapping `WebClient` to ensure thread-safe, non-blocking requests.

## Requirements
- Security configurations permitting login `/api/auth/login` and webhook `/api/telemetry/webhook`.
- Custom JWT decoder/generator utility.
- WebClient client executing POST to `https://thingsboard.cloud/api/auth/login`.

## Related Code Files
- [NEW] [JwtService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/JwtService.java)
- [NEW] [SecurityConfig.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/config/SecurityConfig.java)
- [NEW] [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java)
- [NEW] [AuthController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/AuthController.java)

## Implementation Steps
1. Create `ThingsboardClient` using Spring WebFlux WebClient to wrap ThingsBoard HTTP operations.
2. Implement `JwtService` using Spring Security OAuth2/Jose to sign and verify BFF tokens, encoding the ThingsBoard JWT in a custom claim `tb_token`.
3. Create `AuthController` with `/api/auth/login` endpoint that forwards username/password to `ThingsboardClient`, signs a BFF JWT on success, and returns it.
4. Set up `SecurityConfig` to authenticate Flutter requests using the BFF JWT.

## Todo List
- [ ] Configure JWT signature and key provider
- [ ] Implement `ThingsboardClient` WebClient wrapper
- [ ] Build `/api/auth/login` endpoint
- [ ] Build Spring Security filters

## Success Criteria
- Valid POST to `/api/auth/login` returns a token.
- Protected endpoints reject requests without a valid BFF token.
