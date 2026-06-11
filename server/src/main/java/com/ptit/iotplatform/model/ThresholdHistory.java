package com.ptit.iotplatform.model;

import jakarta.persistence.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "threshold_history")
@Data
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class ThresholdHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.AUTO)
    private UUID id;

    @Column(name = "device_id", nullable = false)
    private String deviceId;

    @Column(name = "dust_high")
    private Double dustHigh;

    @Column(name = "dust_med")
    private Double dustMed;

    @Column(name = "gas_high")
    private Double gasHigh;

    @Column(name = "gas_med")
    private Double gasMed;

    @Column(name = "temp_high")
    private Double tempHigh;

    @Column(name = "hum_low")
    private Double humLow;

    @Column(name = "timestamp", nullable = false)
    private Instant timestamp;
}
