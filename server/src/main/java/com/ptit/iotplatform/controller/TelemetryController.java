package com.ptit.iotplatform.controller;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.ptit.iotplatform.model.TelemetryData;
import com.ptit.iotplatform.model.AlertLog;
import com.ptit.iotplatform.model.ThresholdHistory;
import com.ptit.iotplatform.service.TelemetryService;
import com.ptit.iotplatform.service.ThingsboardClient;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.web.bind.annotation.*;
import reactor.core.publisher.Mono;
import reactor.core.scheduler.Schedulers;

import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Collections;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/devices")
public class TelemetryController {

    private final TelemetryService telemetryService;
    private final ThingsboardClient thingsboardClient;

    public TelemetryController(TelemetryService telemetryService, ThingsboardClient thingsboardClient) {
        this.telemetryService = telemetryService;
        this.thingsboardClient = thingsboardClient;
    }

    public record WebhookPayload(
            @JsonProperty("deviceId") String deviceId,
            @JsonProperty("temperature") Double temperature,
            @JsonProperty("humidity") Double humidity,
            @JsonProperty("dust_ug") Double dustUg,
            @JsonProperty("gas_ppm") Double gasPpm,
            @JsonProperty("auto_mode") Boolean autoMode,
            @JsonProperty("fan_level") Integer fanLevel,
            @JsonProperty("mist_on") Boolean mistOn,
            @JsonProperty("water_low") Boolean waterLow
    ) {}

    // 1. Webhook endpoint for ThingsBoard Rule Engine to push telemetry
    // Configured in SecurityConfig to permitAll
    @PostMapping("/telemetry/webhook")
    public ResponseEntity<Void> receiveWebhook(@RequestBody WebhookPayload payload) {
        if (payload.deviceId() != null) {
            telemetryService.saveTelemetry(
                    payload.deviceId(),
                    payload.temperature(),
                    payload.humidity(),
                    payload.dustUg(),
                    payload.gasPpm(),
                    payload.autoMode(),
                    payload.fanLevel(),
                    payload.mistOn(),
                    payload.waterLow()
            );
        }
        return ResponseEntity.ok().build();
    }

    // 2. Fetch latest telemetry - tries local DB first, falls back to ThingsBoard
    @GetMapping("/{deviceId}/telemetry/latest")
    public Mono<ResponseEntity<Map<String, List<List<Object>>>>> getLatestTelemetry(@PathVariable String deviceId) {
        String token = SecurityContextHolder.getContext().getAuthentication().getCredentials().toString();
        
        return thingsboardClient.getLatestTelemetry(token, deviceId, "temperature,humidity,dust_ug,gas_ppm,auto_mode,fan_level,mist_on,water_low")
                .publishOn(Schedulers.boundedElastic())
                .map(tbMap -> {
                    TelemetryData data = parseThingsboardResponse(deviceId, tbMap);
                    if (data != null) {
                        // Avoid duplicates if ts matches
                        boolean exists = telemetryService.existsByDeviceIdAndTs(deviceId, data.getTs());
                        if (!exists) {
                            telemetryService.saveTelemetry(
                                    data.getDeviceId(),
                                    data.getTemperature(),
                                    data.getHumidity(),
                                    data.getDustUg(),
                                    data.getGasPpm(),
                                    data.getAutoMode(),
                                    data.getFanLevel(),
                                    data.getMistOn(),
                                    data.getWaterLow(),
                                    data.getTs()
                            );
                        }
                        return ResponseEntity.ok(formatLatestResponse(data));
                    }
                    
                    // Fallback to local DB if thingsboard returns empty
                    return telemetryService.getLatestTelemetry(deviceId)
                            .map(localData -> ResponseEntity.ok(formatLatestResponse(localData)))
                            .orElseGet(() -> ResponseEntity.notFound().build());
                })
                .onErrorResume(e -> Mono.fromCallable(() -> telemetryService.getLatestTelemetry(deviceId))
                        .subscribeOn(Schedulers.boundedElastic())
                        .map(opt -> opt.map(localData -> ResponseEntity.ok(formatLatestResponse(localData)))
                                .orElseGet(() -> ResponseEntity.notFound().build())));
    }

    // 3. Fetch historical telemetry from local database
    @GetMapping("/{deviceId}/telemetry/history")
    public ResponseEntity<Map<String, List<Map<String, Object>>>> getHistory(
            @PathVariable String deviceId,
            @RequestParam(value = "range", defaultValue = "oneHour") String range) {

        Instant end = Instant.now();
        Instant start = switch (range) {
            case "oneMinute" -> end.minus(1, ChronoUnit.MINUTES);
            case "oneHour" -> end.minus(1, ChronoUnit.HOURS);
            case "oneDay" -> end.minus(1, ChronoUnit.DAYS);
            case "oneWeek" -> end.minus(7, ChronoUnit.DAYS);
            default -> end.minus(1, ChronoUnit.HOURS);
        };

        List<TelemetryData> history = telemetryService.getHistoricalTelemetry(deviceId, start, end);
        return ResponseEntity.ok(formatHistoryResponse(history));
    }

    @GetMapping("/{deviceId}/alerts/history")
    public ResponseEntity<List<AlertLog>> getAlertHistory(@PathVariable String deviceId) {
        return ResponseEntity.ok(telemetryService.getAlertHistory(deviceId));
    }

    @GetMapping("/{deviceId}/alerts/active")
    public ResponseEntity<List<AlertLog>> getActiveAlerts(@PathVariable String deviceId) {
        return ResponseEntity.ok(telemetryService.getActiveAlerts(deviceId));
    }

    @GetMapping("/{deviceId}/thresholds/history")
    public ResponseEntity<List<ThresholdHistory>> getThresholdHistory(@PathVariable String deviceId) {
        return ResponseEntity.ok(telemetryService.getThresholdHistory(deviceId));
    }

    private Map<String, List<List<Object>>> formatLatestResponse(TelemetryData data) {
        if (data == null) return Collections.emptyMap();
        long ts = data.getTs().toEpochMilli();
        return Map.of(
            "temperature", List.of(List.of(ts, data.getTemperature() != null ? data.getTemperature() : 0.0)),
            "humidity", List.of(List.of(ts, data.getHumidity() != null ? data.getHumidity() : 0.0)),
            "dust_ug", List.of(List.of(ts, data.getDustUg() != null ? data.getDustUg() : 0.0)),
            "gas_ppm", List.of(List.of(ts, data.getGasPpm() != null ? data.getGasPpm() : 0.0)),
            "auto_mode", List.of(List.of(ts, data.getAutoMode() != null ? data.getAutoMode() : true)),
            "fan_level", List.of(List.of(ts, data.getFanLevel() != null ? data.getFanLevel() : 1)),
            "mist_on", List.of(List.of(ts, data.getMistOn() != null ? data.getMistOn() : false)),
            "water_low", List.of(List.of(ts, data.getWaterLow() != null ? data.getWaterLow() : false))
        );
    }

    private Map<String, List<Map<String, Object>>> formatHistoryResponse(List<TelemetryData> historyList) {
        List<Map<String, Object>> temp = new java.util.ArrayList<>();
        List<Map<String, Object>> hum = new java.util.ArrayList<>();
        List<Map<String, Object>> dust = new java.util.ArrayList<>();
        List<Map<String, Object>> gas = new java.util.ArrayList<>();

        for (TelemetryData data : historyList) {
            long ts = data.getTs().toEpochMilli();
            if (data.getTemperature() != null) temp.add(Map.of("ts", ts, "value", data.getTemperature()));
            if (data.getHumidity() != null) hum.add(Map.of("ts", ts, "value", data.getHumidity()));
            if (data.getDustUg() != null) dust.add(Map.of("ts", ts, "value", data.getDustUg()));
            if (data.getGasPpm() != null) gas.add(Map.of("ts", ts, "value", data.getGasPpm()));
        }

        // Return DESC order just like Thingsboard
        Collections.reverse(temp);
        Collections.reverse(hum);
        Collections.reverse(dust);
        Collections.reverse(gas);

        return Map.of(
            "temperature", temp,
            "humidity", hum,
            "dust_ug", dust,
            "gas_ppm", gas
        );
    }

    private TelemetryData parseThingsboardResponse(String deviceId, Map<String, Object> tbMap) {
        try {
            TelemetryData.TelemetryDataBuilder builder = TelemetryData.builder().deviceId(deviceId);
            long maxTs = 0;

            if (tbMap.containsKey("temperature")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("temperature");
                if (!list.isEmpty()) {
                    builder.temperature(Double.parseDouble(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("humidity")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("humidity");
                if (!list.isEmpty()) {
                    builder.humidity(Double.parseDouble(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("dust_ug")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("dust_ug");
                if (!list.isEmpty()) {
                    builder.dustUg(Double.parseDouble(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("gas_ppm")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("gas_ppm");
                if (!list.isEmpty()) {
                    builder.gasPpm(Double.parseDouble(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("auto_mode")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("auto_mode");
                if (!list.isEmpty()) {
                    builder.autoMode(Boolean.parseBoolean(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("fan_level")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("fan_level");
                if (!list.isEmpty()) {
                    builder.fanLevel(Integer.parseInt(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("mist_on")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("mist_on");
                if (!list.isEmpty()) {
                    builder.mistOn(Boolean.parseBoolean(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }
            if (tbMap.containsKey("water_low")) {
                List<Map<String, Object>> list = (List<Map<String, Object>>) tbMap.get("water_low");
                if (!list.isEmpty()) {
                    builder.waterLow(Boolean.parseBoolean(list.getFirst().get("value").toString()));
                    maxTs = Math.max(maxTs, Long.parseLong(list.getFirst().get("ts").toString()));
                }
            }

            builder.ts(maxTs > 0 ? Instant.ofEpochMilli(maxTs) : Instant.now());
            return builder.build();
        } catch (Exception e) {
            return null;
        }
    }
}
