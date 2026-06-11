package com.ptit.iotplatform.service;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;
import org.springframework.web.reactive.function.client.WebClient;
import reactor.core.publisher.Mono;

import java.util.Map;

@Service
public class ThingsboardClient {

    private final WebClient webClient;

    public ThingsboardClient(@Value("${thingsboard.api-url:https://thingsboard.cloud}") String apiUrl) {
        this.webClient = WebClient.builder()
                .baseUrl(apiUrl)
                .defaultHeader(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                .build();
    }

    public record LoginRequest(String username, String password) {}
    public record LoginResponse(String token, String refreshToken) {}
    public record RpcRequest(String method, Object params) {}

    public Mono<LoginResponse> login(String username, String password) {
        return webClient.post()
                .uri("/api/auth/login")
                .bodyValue(new LoginRequest(username, password))
                .retrieve()
                .bodyToMono(LoginResponse.class)
                .onErrorResume(e -> Mono.empty());
    }

    public Mono<Map<String, Object>> getLatestTelemetry(String token, String deviceId, String keys) {
        return webClient.get()
                .uri(uriBuilder -> uriBuilder
                        .path("/api/plugins/telemetry/DEVICE/{deviceId}/values/timeseries")
                        .queryParam("keys", keys)
                        .build(deviceId))
                .header("X-Authorization", "Bearer " + token)
                .retrieve()
                .bodyToMono(Map.class)
                .map(map -> (Map<String, Object>) map)
                .onErrorResume(e -> Mono.empty());
    }

    public Mono<String> sendRpcCommand(String token, String deviceId, String method, Object params) {
        return webClient.post()
                .uri("/api/plugins/rpc/oneway/{deviceId}", deviceId)
                .header("X-Authorization", "Bearer " + token)
                .bodyValue(new RpcRequest(method, params))
                .retrieve()
                .bodyToMono(String.class)
                .defaultIfEmpty("{\"status\":\"success\"}")
                .onErrorResume(e -> Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}"));
    }

    public Mono<String> sendTwoWayRpcCommand(String token, String deviceId, String method, Object params) {
        return webClient.post()
                .uri("/api/plugins/rpc/twoway/{deviceId}", deviceId)
                .header("X-Authorization", "Bearer " + token)
                .bodyValue(new RpcRequest(method, params))
                .retrieve()
                .bodyToMono(String.class)
                .defaultIfEmpty("{\"status\":\"success\"}")
                .onErrorResume(e -> Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}"));
    }
}
