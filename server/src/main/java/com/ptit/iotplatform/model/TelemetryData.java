package com.ptit.iotplatform.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "telemetry_data")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class TelemetryData {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "temperature")
    private Double temperature;

    @Column(name = "humidity")
    private Double humidity;

    @Column(name = "dust_ug")
    private Double dustUg;

    @Column(name = "gas_ppm")
    private Double gasPpm;

    @Column(name = "auto_mode")
    private Boolean autoMode;

    @Column(name = "fan_level")
    private Integer fanLevel;

    @Column(name = "mist_on")
    private Boolean mistOn;

    @Column(name = "water_low")
    private Boolean waterLow;

    @Column(name = "ts", nullable = false)
    private Instant ts;
}
