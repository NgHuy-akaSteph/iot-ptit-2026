# Phase 01: Backend (Spring BFF) Transactional & Threading Fixes

## Context Links
- [debugger report](file:///h:/SideProjects/iot-ptit-2026/plans/reports/debugger-260526-0735-fix-auto-manual-speed-rpc-bug.md)
- [plan.md](file:///h:/SideProjects/iot-ptit-2026/plans/260526-0735-fix-auto-manual-speed-rpc-bug/plan.md)

## Overview
- **Priority**: HIGH
- **Current Status**: COMPLETE
- **Description**: Wrap blocking JPA operations in `RpcService` within programmatic transactions using `TransactionTemplate` and schedule them on `Schedulers.boundedElastic()` to avoid blocking the WebFlux event loop.

## Key Insights
- Spring WebFlux controller requests execute reactively. Netty EventLoop threads must never be blocked.
- Standard `@Transactional` relies on thread-local storage, which fails across reactive operations. Injecting `PlatformTransactionManager` allows programmatic transactions with `TransactionTemplate` that span reactive callbacks safely.

## Requirements
- Prevent Spring Boot backend from returning HTTP 500 when executing RPC commands.
- Correctly save PENDING, SUCCESS, or FAILED status of commands in `command_log` table.

## Architecture
```
Flutter client -> BFF (Netty) -> RpcService -> [boundedElastic] -> DB (Pending log)
BFF -> ThingsBoard API (WebClient) -> Async callback -> [boundedElastic] -> DB (Success/Failed log)
```

## Related Code Files
- [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java)

## Implementation Steps
1. Import `PlatformTransactionManager` and `TransactionTemplate` in `RpcService.java`.
2. Update constructor to receive `PlatformTransactionManager` and construct `TransactionTemplate`.
3. Wrap initial write and reactive callback maps inside `transactionTemplate.execute(...)` scheduled on `Schedulers.boundedElastic()`.

## Todo List
- [ ] Modify `RpcService.java` to support programmatic transactions and elastic scheduler mapping.
- [ ] Compile server using Gradle and ensure no compilation errors.

## Success Criteria
- Backend compiles cleanly.
- `/api/devices/{deviceId}/rpc` returns HTTP 200 containing status result.

## Risk Assessment
- *Risk*: Transaction rollback during reactive callbacks.
- *Mitigation*: Ensure database saves are wrapped in try-catch or returned values are correct.

## Security Considerations
- Verify authorization credentials and device ownership mapping is preserved.

## Next Steps
- Move to Phase 02 (Device firmware modification).
