package com.ptit.iotplatform.controller;

import com.ptit.iotplatform.service.JwtService;
import com.ptit.iotplatform.service.ThingsboardClient;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;

import java.util.Map;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final ThingsboardClient thingsboardClient;
    private final JwtService jwtService;

    public AuthController(ThingsboardClient thingsboardClient, JwtService jwtService) {
        this.thingsboardClient = thingsboardClient;
        this.jwtService = jwtService;
    }

    public record LoginRequest(String username, String password) {}
    public record TokenResponse(String token, String tbToken) {}

    @PostMapping("/login")
    public Mono<ResponseEntity<TokenResponse>> login(@RequestBody LoginRequest request) {
        return thingsboardClient.login(request.username(), request.password())
                .map(tbResponse -> {
                    String bffToken = jwtService.generateToken(request.username(), tbResponse.token());
                    return ResponseEntity.ok(new TokenResponse(bffToken, tbResponse.token()));
                })
                .defaultIfEmpty(ResponseEntity.status(HttpStatus.UNAUTHORIZED).build());
    }
}
