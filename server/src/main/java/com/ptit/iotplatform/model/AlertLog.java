package com.ptit.iotplatform.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "alert_log")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class AlertLog {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "alert_type", nullable = false)
    private String alertType; // e.g. "DUST", "GAS", "TEMPERATURE", "HUMIDITY", "WATER_LOW"

    @Column(name = "severity", nullable = false)
    private String severity; // e.g. "CRITICAL", "WARNING"

    @Column(name = "message", nullable = false)
    private String message;

    @Column(name = "value")
    private Double value;

    @Column(name = "threshold_value")
    private Double thresholdValue;

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;

    @Column(name = "resolved")
    private Boolean resolved;

    @Column(name = "resolved_at")
    private Instant resolvedAt;
}
