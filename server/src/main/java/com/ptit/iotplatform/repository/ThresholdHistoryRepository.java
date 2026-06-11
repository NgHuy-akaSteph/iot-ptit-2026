package com.ptit.iotplatform.repository;

import com.ptit.iotplatform.model.ThresholdHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface ThresholdHistoryRepository extends JpaRepository<ThresholdHistory, UUID> {
    List<ThresholdHistory> findByDeviceIdOrderByTimestampDesc(String deviceId);
    Optional<ThresholdHistory> findFirstByDeviceIdOrderByTimestampDesc(String deviceId);
}
