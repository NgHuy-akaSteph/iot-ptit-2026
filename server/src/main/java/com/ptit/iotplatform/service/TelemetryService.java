package com.ptit.iotplatform.service;

import com.ptit.iotplatform.model.TelemetryData;
import com.ptit.iotplatform.repository.TelemetryRepository;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
public class TelemetryService {

    private final TelemetryRepository telemetryRepository;

    public TelemetryService(TelemetryRepository telemetryRepository) {
        this.telemetryRepository = telemetryRepository;
    }

    @Transactional
    public TelemetryData saveTelemetry(String deviceId, Double temperature, Double humidity, 
                                       Double dustUg, Double gasPpm, Boolean autoMode, Integer fanLevel) {
        TelemetryData telemetryData = TelemetryData.builder()
                .deviceId(deviceId)
                .temperature(temperature)
                .humidity(humidity)
                .dustUg(dustUg)
                .gasPpm(gasPpm)
                .autoMode(autoMode)
                .fanLevel(fanLevel)
                .ts(Instant.now())
                .build();
        return telemetryRepository.save(telemetryData);
    }

    @Transactional(readOnly = true)
    public Optional<TelemetryData> getLatestTelemetry(String deviceId) {
        return telemetryRepository.findFirstByDeviceIdOrderByTsDesc(deviceId);
    }

    @Transactional(readOnly = true)
    public List<TelemetryData> getHistoricalTelemetry(String deviceId, Instant start, Instant end) {
        return telemetryRepository.findByDeviceIdAndTsBetweenOrderByTsAsc(deviceId, start, end);
    }
}
