package com.ptit.iotplatform.service;

import com.ptit.iotplatform.model.TelemetryData;
import com.ptit.iotplatform.model.ThresholdHistory;
import com.ptit.iotplatform.model.AlertLog;
import com.ptit.iotplatform.repository.TelemetryRepository;
import com.ptit.iotplatform.repository.ThresholdHistoryRepository;
import com.ptit.iotplatform.repository.AlertLogRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

@Service
public class TelemetryService {

    private final TelemetryRepository telemetryRepository;
    private final ThresholdHistoryRepository thresholdHistoryRepository;
    private final AlertLogRepository alertLogRepository;

    public TelemetryService(TelemetryRepository telemetryRepository,
                            ThresholdHistoryRepository thresholdHistoryRepository,
                            AlertLogRepository alertLogRepository) {
        this.telemetryRepository = telemetryRepository;
        this.thresholdHistoryRepository = thresholdHistoryRepository;
        this.alertLogRepository = alertLogRepository;
    }

    @Transactional
    public TelemetryData saveTelemetry(String deviceId, Double temperature, Double humidity, 
                                       Double dustUg, Double gasPpm, Boolean autoMode, Integer fanLevel,
                                       Boolean mistOn, Boolean waterLow) {
        TelemetryData telemetryData = TelemetryData.builder()
                .deviceId(deviceId)
                .temperature(temperature)
                .humidity(humidity)
                .dustUg(dustUg)
                .gasPpm(gasPpm)
                .autoMode(autoMode)
                .fanLevel(fanLevel)
                .mistOn(mistOn)
                .waterLow(waterLow)
                .ts(Instant.now())
                .build();
        
        TelemetryData saved = telemetryRepository.save(telemetryData);
        try {
            checkAndLogAlerts(saved);
        } catch (Exception e) {
            // Keep saving telemetry even if alert logging fails
        }
        return saved;
    }

    @Transactional
    public TelemetryData saveTelemetry(String deviceId, Double temperature, Double humidity, 
                                       Double dustUg, Double gasPpm, Boolean autoMode, Integer fanLevel,
                                       Boolean mistOn, Boolean waterLow, Instant timestamp) {
        TelemetryData telemetryData = TelemetryData.builder()
                .deviceId(deviceId)
                .temperature(temperature)
                .humidity(humidity)
                .dustUg(dustUg)
                .gasPpm(gasPpm)
                .autoMode(autoMode)
                .fanLevel(fanLevel)
                .mistOn(mistOn)
                .waterLow(waterLow)
                .ts(timestamp != null ? timestamp : Instant.now())
                .build();
        
        TelemetryData saved = telemetryRepository.save(telemetryData);
        try {
            checkAndLogAlerts(saved);
        } catch (Exception e) {
            // Keep saving telemetry even if alert logging fails
        }
        return saved;
    }

    @Transactional(readOnly = true)
    public Optional<TelemetryData> getLatestTelemetry(String deviceId) {
        return telemetryRepository.findFirstByDeviceIdOrderByTsDesc(deviceId);
    }

    @Transactional(readOnly = true)
    public List<TelemetryData> getHistoricalTelemetry(String deviceId, Instant start, Instant end) {
        return telemetryRepository.findByDeviceIdAndTsBetweenOrderByTsAsc(deviceId, start, end);
    }

    @Transactional(readOnly = true)
    public boolean existsByDeviceIdAndTs(String deviceId, Instant ts) {
        return telemetryRepository.existsByDeviceIdAndTs(deviceId, ts);
    }

    @Transactional(readOnly = true)
    public List<AlertLog> getAlertHistory(String deviceId) {
        return alertLogRepository.findByDeviceIdOrderByTimestampDesc(deviceId);
    }

    @Transactional(readOnly = true)
    public List<AlertLog> getActiveAlerts(String deviceId) {
        return alertLogRepository.findByDeviceIdAndResolvedFalse(deviceId);
    }

    @Transactional(readOnly = true)
    public List<ThresholdHistory> getThresholdHistory(String deviceId) {
        return thresholdHistoryRepository.findByDeviceIdOrderByTimestampDesc(deviceId);
    }

    private void checkAndLogAlerts(TelemetryData data) {
        String deviceId = data.getDeviceId();
        Instant now = data.getTs() != null ? data.getTs() : Instant.now();

        // Get latest thresholds or fall back to defaults
        var latestThresholdOpt = thresholdHistoryRepository.findFirstByDeviceIdOrderByTimestampDesc(deviceId);
        double dustHigh = latestThresholdOpt.map(t -> t.getDustHigh() != null ? t.getDustHigh() : 150.0).orElse(150.0);
        double dustMed = latestThresholdOpt.map(t -> t.getDustMed() != null ? t.getDustMed() : 75.0).orElse(75.0);
        double gasHigh = latestThresholdOpt.map(t -> t.getGasHigh() != null ? t.getGasHigh() : 800.0).orElse(800.0);
        double gasMed = latestThresholdOpt.map(t -> t.getGasMed() != null ? t.getGasMed() : 400.0).orElse(400.0);
        double tempHigh = latestThresholdOpt.map(t -> t.getTempHigh() != null ? t.getTempHigh() : 35.0).orElse(35.0);
        double humLow = latestThresholdOpt.map(t -> t.getHumLow() != null ? t.getHumLow() : 60.0).orElse(60.0);

        // 1. Evaluate DUST
        evaluateAlert(deviceId, "DUST", data.getDustUg(), dustHigh, dustMed, now,
                "Bụi mịn vượt ngưỡng nguy hiểm!", "Bụi mịn vượt ngưỡng cảnh báo!");

        // 2. Evaluate GAS
        evaluateAlert(deviceId, "GAS", data.getGasPpm(), gasHigh, gasMed, now,
                "Khí gas vượt ngưỡng nguy hiểm!", "Khí gas vượt ngưỡng cảnh báo!");

        // 3. Evaluate WATER_LOW
        evaluateBooleanAlert(deviceId, "WATER_LOW", data.getWaterLow(), now, "CRITICAL",
                "Cạn nước trong bình!");

        // 4. Evaluate TEMPERATURE
        evaluateAlert(deviceId, "TEMPERATURE", data.getTemperature(), tempHigh, null, now,
                "Nhiệt độ vượt ngưỡng nguy hiểm!", null);

        // 5. Evaluate HUMIDITY (too low is bad)
        evaluateLowerAlert(deviceId, "HUMIDITY", data.getHumidity(), humLow, now, "WARNING",
                "Độ ẩm quá thấp!");
    }

    private void evaluateAlert(String deviceId, String alertType, Double value, Double highThreshold, Double medThreshold, Instant now, String highMsg, String medMsg) {
        if (value == null) return;

        String currentSeverity = null;
        String currentMessage = null;
        Double currentThreshold = null;

        if (highThreshold != null && value > highThreshold) {
            currentSeverity = "CRITICAL";
            currentMessage = highMsg;
            currentThreshold = highThreshold;
        } else if (medThreshold != null && value > medThreshold) {
            currentSeverity = "WARNING";
            currentMessage = medMsg;
            currentThreshold = medThreshold;
        }

        handleAlertState(deviceId, alertType, currentSeverity, currentMessage, value, currentThreshold, now);
    }

    private void evaluateLowerAlert(String deviceId, String alertType, Double value, Double lowThreshold, Instant now, String severity, String message) {
        if (value == null) return;

        String currentSeverity = null;
        String currentMessage = null;
        Double currentThreshold = null;

        if (lowThreshold != null && value < lowThreshold && value > 0.0) {
            currentSeverity = severity;
            currentMessage = message;
            currentThreshold = lowThreshold;
        }

        handleAlertState(deviceId, alertType, currentSeverity, currentMessage, value, currentThreshold, now);
    }

    private void evaluateBooleanAlert(String deviceId, String alertType, Boolean isAlertActive, Instant now, String severity, String message) {
        if (isAlertActive == null) return;

        String currentSeverity = Boolean.TRUE.equals(isAlertActive) ? severity : null;
        String currentMessage = Boolean.TRUE.equals(isAlertActive) ? message : null;

        handleAlertState(deviceId, alertType, currentSeverity, currentMessage, null, null, now);
    }

    private void handleAlertState(String deviceId, String alertType, String currentSeverity, String currentMessage, Double value, Double thresholdVal, Instant now) {
        var activeAlertOpt = alertLogRepository.findFirstByDeviceIdAndAlertTypeAndResolvedFalse(deviceId, alertType);

        if (currentSeverity == null) {
            // SAFE state: Resolve active alert if present
            if (activeAlertOpt.isPresent()) {
                AlertLog activeAlert = activeAlertOpt.get();
                activeAlert.setResolved(true);
                activeAlert.setResolvedAt(now);
                alertLogRepository.save(activeAlert);
            }
        } else {
            // ALERT state
            if (activeAlertOpt.isEmpty()) {
                // Create new alert
                AlertLog alert = AlertLog.builder()
                        .deviceId(deviceId)
                        .alertType(alertType)
                        .severity(currentSeverity)
                        .message(currentMessage)
                        .value(value)
                        .thresholdValue(thresholdVal)
                        .timestamp(now)
                        .resolved(false)
                        .build();
                alertLogRepository.save(alert);
            } else {
                AlertLog activeAlert = activeAlertOpt.get();
                if (!activeAlert.getSeverity().equals(currentSeverity)) {
                    // Severity changed: Resolve current one and create new one
                    activeAlert.setResolved(true);
                    activeAlert.setResolvedAt(now);
                    alertLogRepository.save(activeAlert);

                    AlertLog alert = AlertLog.builder()
                            .deviceId(deviceId)
                            .alertType(alertType)
                            .severity(currentSeverity)
                            .message(currentMessage)
                            .value(value)
                            .thresholdValue(thresholdVal)
                            .timestamp(now)
                            .resolved(false)
                            .build();
                    alertLogRepository.save(alert);
                }
            }
        }
    }
}
