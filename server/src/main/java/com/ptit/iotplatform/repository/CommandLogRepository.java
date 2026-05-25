package com.ptit.iotplatform.repository;

import com.ptit.iotplatform.model.CommandLog;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.UUID;

@Repository
public interface CommandLogRepository extends JpaRepository<CommandLog, UUID> {

    List<CommandLog> findByDeviceIdOrderByTimestampDesc(String deviceId);
}
