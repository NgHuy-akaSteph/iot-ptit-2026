package com.ptit.iotplatform.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ptit.iotplatform.model.CommandLog;
import com.ptit.iotplatform.repository.CommandLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Instant;

@Service
public class RpcService {

    private final CommandLogRepository commandLogRepository;
    private final ThingsboardClient thingsboardClient;
    private final TransactionTemplate transactionTemplate;
    private final ObjectMapper objectMapper = new ObjectMapper();

    public RpcService(CommandLogRepository commandLogRepository, 
                      ThingsboardClient thingsboardClient, 
                      PlatformTransactionManager transactionManager) {
        this.commandLogRepository = commandLogRepository;
        this.thingsboardClient = thingsboardClient;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public Mono<String> sendRpcCommand(String username, String tbToken, String deviceId, String method, Object params) {
        // 1. Create and save pending command log asynchronously on boundedElastic
        return Mono.fromCallable(() -> {
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
            return transactionTemplate.execute(status -> commandLogRepository.save(log));
        })
        .subscribeOn(Schedulers.boundedElastic())
        .flatMap(savedLog -> 
            thingsboardClient.sendRpcCommand(tbToken, deviceId, method, params)
                    .publishOn(Schedulers.boundedElastic())
                    .map(response -> {
                        transactionTemplate.execute(status -> {
                            savedLog.setResponse(response);
                            if (response.contains("\"success\"") || response.contains("SUCCESS") || !response.contains("error")) {
                                savedLog.setStatus("SUCCESS");
                            } else {
                                savedLog.setStatus("FAILED");
                            }
                            commandLogRepository.save(savedLog);
                            return null;
                        });
                        return response;
                    })
                    .onErrorResume(e -> {
                        transactionTemplate.execute(status -> {
                            savedLog.setStatus("FAILED");
                            savedLog.setResponse(e.getMessage());
                            commandLogRepository.save(savedLog);
                            return null;
                        });
                        return Mono.just("{\"status\":\"error\",\"message\":\"" + e.getMessage() + "\"}");
                    })
        );
    }
}

