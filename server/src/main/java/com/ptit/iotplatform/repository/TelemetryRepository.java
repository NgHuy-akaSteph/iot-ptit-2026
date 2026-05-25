package com.ptit.iotplatform.repository;

import com.ptit.iotplatform.model.TelemetryData;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Repository
public interface TelemetryRepository extends JpaRepository<TelemetryData, UUID> {

    List<TelemetryData> findByDeviceIdAndTsBetweenOrderByTsAsc(String deviceId, Instant startTs, Instant endTs);

    Optional<TelemetryData> findFirstByDeviceIdOrderByTsDesc(String deviceId);

    @Query("SELECT t FROM TelemetryData t WHERE t.deviceId = :deviceId ORDER BY t.ts DESC")
    List<TelemetryData> findLatestByDeviceId(String deviceId, Pageable pageable);
}
