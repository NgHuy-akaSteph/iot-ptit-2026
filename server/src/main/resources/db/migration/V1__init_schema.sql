CREATE TABLE telemetry_data (
    id UUID PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    temperature DOUBLE PRECISION,
    humidity DOUBLE PRECISION,
    dust_ug DOUBLE PRECISION,
    gas_ppm DOUBLE PRECISION,
    auto_mode BOOLEAN,
    fan_level INTEGER,
    ts TIMESTAMP NOT NULL
);

CREATE TABLE command_log (
    id UUID PRIMARY KEY,
    device_id VARCHAR(255) NOT NULL,
    username VARCHAR(255) NOT NULL,
    method VARCHAR(255) NOT NULL,
    params TEXT,
    status VARCHAR(50) NOT NULL,
    timestamp TIMESTAMP NOT NULL,
    response TEXT
);
