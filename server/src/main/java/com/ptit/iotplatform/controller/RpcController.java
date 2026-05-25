package com.ptit.iotplatform.controller;

import com.ptit.iotplatform.service.RpcService;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

@RestController
@RequestMapping("/api/devices")
public class RpcController {

    private final RpcService rpcService;

    public RpcController(RpcService rpcService) {
        this.rpcService = rpcService;
    }

    public record RpcCommandRequest(String method, Object params) {}

    @PostMapping("/{deviceId}/rpc")
    public Mono<ResponseEntity<String>> sendRpc(
            @PathVariable String deviceId,
            @RequestBody RpcCommandRequest request) {

        var auth = SecurityContextHolder.getContext().getAuthentication();
        String username = auth.getName();
        String tbToken = auth.getCredentials().toString();

        return rpcService.sendRpcCommand(username, tbToken, deviceId, request.method(), request.params())
                .map(ResponseEntity::ok)
                .defaultIfEmpty(ResponseEntity.badRequest().build());
    }
}
