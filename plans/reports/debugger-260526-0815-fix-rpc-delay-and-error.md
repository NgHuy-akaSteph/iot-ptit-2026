# Debugger Report: Fix RPC Delay and Error
Date: 260526
Time: 0815
Slug: fix-rpc-delay-and-error

## 1. Root Cause Identification

### Issue A: Large RPC Delay (10 seconds or more)
- **Symptom**: Toggling automatic/manual mode or setting the fan speed causes a massive delay (up to 10 seconds), and often returns an error.
- **Cause**: The backend `ThingsboardClient.sendRpcCommand` uses a two-way RPC request (`/api/plugins/rpc/twoway/{deviceId}`). Two-way RPC blocks the calling HTTP thread and waits for the physical device to respond via MQTT. If the device is offline, slow to connect, or fails to subscribe to the request topic in a timely manner, ThingsBoard waits for the default timeout (10 seconds) and then throws a timeout exception.
- **Analysis**: Since the Flutter client does not use or inspect the HTTP response body for the RPC endpoint (it only checks `response.statusCode == 200`), there is no functional reason to use two-way RPC. Switching to a one-way RPC (`/api/plugins/rpc/oneway/{deviceId}`) will execute instantly (within milliseconds) by queuing the command in ThingsBoard and returning success immediately, avoiding any delay.

### Issue B: Incorrect Error Propagation (Silent/Fake Success)
- **Symptom**: When the RPC actually fails (e.g., due to ThingsBoard token expiry or communication failure), the Flutter client still thinks it succeeded and updates the UI switch, while in reality, the hardware state remains unchanged.
- **Cause**: 
  - In `ThingsboardClient.java`, the `sendRpcCommand` method catches any WebClient error and returns a successful Mono emitting an error JSON string:
    ```java
    .onErrorResume(e -> Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}"))
    ```
  - In `RpcService.java`, the method maps this response and updates the log status to `FAILED`, but still returns the JSON string to `RpcController`.
  - `RpcController` maps the return value to `ResponseEntity::ok`, which sends an HTTP **200 OK** to the Flutter client with the error JSON in the body.
  - The Flutter client checks only `response.statusCode == 200` to determine success. Therefore, it incorrectly interprets the failed RPC command as a success!

## 2. Proposed Solution

### Backend:
1. **Switch to One-way RPC**:
   Change `/api/plugins/rpc/twoway/{deviceId}` to `/api/plugins/rpc/oneway/{deviceId}` in `ThingsboardClient.java`.
2. **Propagate Errors via HTTP Status Codes**:
   Update `RpcController.java` to inspect the RPC response body. If the response contains `"status":"error"` or `"error"`, return an HTTP **500 Internal Server Error** (or HTTP 400) instead of HTTP **200 OK**. This allows the Flutter client to correctly trigger its exception handling and show the error SnackBar.
3. **Enhance Reactive Safety**:
   Wrap any blocking JPA calls in `TelemetryController.java` inside `Mono.fromCallable` scheduled on `Schedulers.boundedElastic()` to prevent blocking the reactive thread pool.

## 3. Verification Plan
- **Backend Build**: Compile and verify Spring Boot backend runs successfully with tests passing.
- **Manual Verification**: Toggle auto mode and fan speed on the client, verifying that one-way RPC calls are instantaneous, and that database command logs are stored as SUCCESS immediately.
