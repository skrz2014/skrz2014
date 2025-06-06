CREATE TABLE IF NOT EXISTS ROLE_CLONE_LOG (
    LOG_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    PROCEDURE_NAME VARCHAR DEFAULT 'CLONE_ROLE_PROC',
    SOURCE_ROLE VARCHAR,
    TARGET_ROLE VARCHAR,
    ACTION VARCHAR,
    STATUS VARCHAR,
    MESSAGE VARCHAR,
    SERVICENOW_TASK VARCHAR
);
