-- Alter telemetry_data to add mist_on and water_low
ALTER TABLE telemetry_data ADD COLUMN mist_on BOOLEAN;
ALTER TABLE telemetry_data ADD COLUMN water_low BOOLEAN;

-- Create threshold_history table
CREATE TABLE threshold_history (
    id UUID PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    dust_high DOUBLE PRECISION,
    dust_med DOUBLE PRECISION,
    gas_high DOUBLE PRECISION,
    gas_med DOUBLE PRECISION,
    temp_high DOUBLE PRECISION,
    hum_low DOUBLE PRECISION,
    timestamp TIMESTAMP NOT NULL
);

-- Create alert_log table
CREATE TABLE alert_log (
    id UUID PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    message VARCHAR(255) NOT NULL,
    value DOUBLE PRECISION,
    threshold_value DOUBLE PRECISION,
    timestamp TIMESTAMP NOT NULL,
    resolved BOOLEAN DEFAULT FALSE,
    resolved_at TIMESTAMP
);
