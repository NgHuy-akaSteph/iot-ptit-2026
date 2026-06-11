package com.ptit.iotplatform.repository;

import com.ptit.iotplatform.model.AlertLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface AlertLogRepository extends JpaRepository<AlertLog, UUID> {
    List<AlertLog> findByDeviceIdOrderByTimestampDesc(String deviceId);
    List<AlertLog> findByDeviceIdAndResolvedFalse(String deviceId);
    Optional<AlertLog> findFirstByDeviceIdAndAlertTypeAndResolvedFalse(String deviceId, String alertType);
}
