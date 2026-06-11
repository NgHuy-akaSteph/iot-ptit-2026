# Debugger Report: Fix Auto-Manual & Speed Change RPC Bug
Date: 260526
Time: 0735
Slug: fix-auto-manual-speed-rpc-bug

## 1. Root Cause Identification

### Issue A: "Không thể thay đổi chế độ tự động" (Cannot change auto mode) on Flutter Client
- **Symptom**: Toggling the "Chế độ tự động" switch fails, throwing SnackBar error in UI.
- **Backend Error**: `RpcService.sendRpcCommand(...)` performs a blocking `commandLogRepository.save(log)` JPA call inside reactive WebFlux streams (`.map` and `.onErrorResume`).
- **Technical Cause**: 
  - Standard Spring `@Transactional` is thread-bound (`ThreadLocal`). When `sendRpcCommand` returns the `Mono`, the executing thread exits the method and the transaction commits/closes.
  - The reactive `.map` and `.onErrorResume` operators run asynchronously on Netty EventLoop threads (`reactor-http-nio-*`), which lack active transaction contexts and session managers.
  - Calling blocking JPA `save()` on detached/unmanaged entities from EventLoop threads blocks Netty and throws transaction/session exceptions, causing an HTTP 500 error on the BFF.
  - Flutter client receives 500 instead of 200, returning `false` and triggering the UI failure.

### Issue B: "Thay đổi tốc độ" (Changing fan speed) Failure
- **Symptom**: Speed selection (Thấp, Trung, Cao) does not update the fan speed or fails.
- **ESP32 Error**: `device/src/main.cpp` processes `setFan` via:
  ```cpp
  String rawParam = doc["params"].as<String>();
  fanLevel = rawParam.toInt();
  ```
- **Technical Cause**:
  - The Flutter client sends `level` as an integer (e.g. `1`, `2`, `3`). The BFF and ThingsBoard proxy it as a JSON numeric value.
  - In ArduinoJson 6, calling `.as<String>()` on a numeric node returns a null/empty string (`""`).
  - Thus, `rawParam` is parsed as `""` and `rawParam.toInt()` returns `0`, causing the fan to be set to level `0` (off) instead of `1`, `2`, or `3`.

## 2. Proposed Solution

### Backend Solution:
- Inject `PlatformTransactionManager` into `RpcService` and construct a `TransactionTemplate` to explicitly run database transactions.
- Offload all blocking JPA operations to `Schedulers.boundedElastic()` to keep the Netty EventLoop non-blocking.
- Wrap internal database saves inside `.map(...)` and `.onErrorResume(...)` in `transactionTemplate.execute(...)` calls on the elastic scheduler.

### ESP32 (Device) Solution:
- Upgrade parsing logic in `device/src/main.cpp` to robustly check if `doc["params"]` is an integer or string before casting.
- Implement clear fallback options to safely parse fan level values.

## 3. Verification Plan
- **Backend Build**: Compile and verify Spring Boot backend runs successfully.
- **ESP32 Compile**: Verify Arduino C++ code parses correctly.
- **Manual Verification**: Toggle auto mode and speed on Flutter UI and observe device alerts and database persistence.
