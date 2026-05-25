package com.ptit.iotplatform.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "command_log")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class CommandLog {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "username", nullable = false)
    private String username;

    @Column(name = "method", nullable = false)
    private String method;

    @Column(name = "params", columnDefinition = "TEXT")
    private String params;

    @Column(name = "status", nullable = false, length = 50)
    private String status; // PENDING, SUCCESS, FAILED

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;

    @Column(name = "response", columnDefinition = "TEXT")
    private String response;
}
