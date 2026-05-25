package com.ptit.iotplatform.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ptit.iotplatform.model.CommandLog;
import com.ptit.iotplatform.repository.CommandLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import reactor.core.publisher.Mono;

import java.time.Instant;

@Service
public class RpcService {

    private final CommandLogRepository commandLogRepository;
    private final ThingsboardClient thingsboardClient;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RpcService(CommandLogRepository commandLogRepository, ThingsboardClient thingsboardClient) {
        this.commandLogRepository = commandLogRepository;
        this.thingsboardClient = thingsboardClient;
    }

    @Transactional
    public Mono<String> sendRpcCommand(String username, String tbToken, String deviceId, String method, Object params) {
        // 1. Create and save pending command log
        CommandLog log = CommandLog.builder()
                .deviceId(deviceId)
                .username(username)
                .method(method)
                .status("PENDING")
                .timestamp(Instant.now())
                .build();
        try {
            log.setParams(objectMapper.writeValueAsString(params));
        } catch (Exception e) {
            log.setParams(params.toString());
        }

        // Save initial state (runs in active transaction)
        final CommandLog savedLog = commandLogRepository.save(log);

        // 2. Call Thingsboard RPC
        return thingsboardClient.sendRpcCommand(tbToken, deviceId, method, params)
                .map(response -> {
                    // Update log status based on response
                    savedLog.setResponse(response);
                    if (response.contains("\"success\"") || response.contains("SUCCESS") || !response.contains("error")) {
                        savedLog.setStatus("SUCCESS");
                    } else {
                        savedLog.setStatus("FAILED");
                    }
                    commandLogRepository.save(savedLog);
                    return response;
                })
                .onErrorResume(e -> {
                    savedLog.setStatus("FAILED");
                    savedLog.setResponse(e.getMessage());
                    commandLogRepository.save(savedLog);
                    return Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}");
                });
    }
}
