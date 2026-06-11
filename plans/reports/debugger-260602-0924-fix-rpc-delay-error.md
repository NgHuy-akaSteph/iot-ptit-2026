# Root Cause Analysis: RPC Delay and Control Error

## Context & Symptoms
- **Symptom 1**: Switching from Auto to Manual (and vice-versa) or adjusting fan level in Flutter app has a delay, shows a red error snackbar ("Không thể thay đổi chế độ tự động" / "Không thể thay đổi mức quạt"), but the hardware still performs the command.
- **Symptom 2**: The switch/fan buttons eventually update in the UI to the correct state after a short delay despite the error.

---

## Technical Investigation & Root Cause

### 1. The Empty-Body Reactive Bug (Severe)
- **File**: [ThingsboardClient.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/ThingsboardClient.java#L50-L58)
- **Code**:
  ```java
  public Mono<String> sendRpcCommand(String token, String deviceId, String method, Object params) {
      return webClient.post()
              .uri("/api/plugins/rpc/oneway/{deviceId}", deviceId)
              .header("X-Authorization", "Bearer " + token)
              .bodyValue(new RpcRequest(method, params))
              .retrieve()
              .bodyToMono(String.class)
              .onErrorResume(e -> Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}"));
  }
  ```
- **Analysis**:
  - The server sends a **one-way** (lightweight) RPC to ThingsBoard via `/api/plugins/rpc/oneway/{deviceId}`.
  - ThingsBoard lightweight one-way RPC returns **HTTP 200 OK with an empty body**.
  - In WebClient, `.bodyToMono(String.class)` returns an **empty Mono** (`Mono.empty()`) when the response body is empty.
  - This empty Mono propagates through [RpcService.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/service/RpcService.java#L48-L73). Because it is empty, `.flatMap()` skips the database update `map` block (so logs stay in `PENDING` status forever) and returns `Mono.empty()`.
  - In [RpcController.java](file:///h:/SideProjects/iot-ptit-2026/server/src/main/java/com/ptit/iotplatform/controller/RpcController.java#L21-L38), the empty Mono triggers `.defaultIfEmpty(ResponseEntity.badRequest().build())`.
  - Therefore, the BFF server returns **HTTP 400 Bad Request** to the mobile client!

### 2. Mobile App Behavior
- **File**: [thingsboard_service.dart](file:///h:/SideProjects/iot-ptit-2026/client/lib/service/thingsboard_service.dart#L107-L127)
- **Code**:
  ```dart
  Future<bool> _sendRpcCommand(String method, dynamic params) async {
    try {
      final response = await _dio.post('$_baseUrl/devices/$deviceId/rpc', ...);
      return response.statusCode == 200;
    } catch (e) {
      return false; // Triggers snackbar error
    }
  }
  ```
- **Analysis**:
  - The BFF returns 400 Bad Request. Dio throws an exception, `_sendRpcCommand` returns `false`.
  - The UI does not update its state immediately and displays the red error snackbar.
  - However, because it was a one-way RPC, ThingsBoard *did* successfully forward the command via MQTT to the ESP32.
  - The ESP32 receives the MQTT command, changes its state, and publishes the new state as telemetry back to ThingsBoard.
  - The Flutter client's WebSocket telemetry subscription (`_wsService.telemetryStream`) receives the updated telemetry from the ESP32 and updates `_currentData` via `setState`.
  - This explains why the toggle switch eventually updates itself anyway.

---

## Action Plan

### Step 1: Fix BFF WebClient Empty Response Handling
Modify `ThingsboardClient.java` to return a successful status JSON if the response is empty instead of completing as an empty Mono:
```java
return webClient.post()
        .uri("/api/plugins/rpc/oneway/{deviceId}", deviceId)
        .header("X-Authorization", "Bearer " + token)
        .bodyValue(new RpcRequest(method, params))
        .retrieve()
        .bodyToMono(String.class)
        .defaultIfEmpty("{\"status\":\"success\"}") // Prevent empty Mono
        .onErrorResume(e -> Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}"));
```

### Step 2: Optimistic UI Updates in Client (Optional but highly recommended)
Currently, the mobile client waits for the BFF HTTP call to finish (which takes 1-2s due to Render cold starts/routing latency) before toggling the switch.
By updating the switch state *before* sending the request and rolling back only on failure, we can completely eliminate the visual delay.
