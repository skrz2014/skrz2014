CREATE OR REPLACE PROCEDURE CLONE_ROLE_PROC(
    P_SOURCE_ROLE_NAME VARCHAR,
    P_TARGET_ROLE_NAME VARCHAR,
    P_LOG_TABLE_NAME VARCHAR,
    P_SERVICENOW_TASK VARCHAR -- New parameter
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS CALLER
AS
$$
DECLARE
    V_LOG_STATEMENT VARCHAR;
    V_MESSAGE VARCHAR;
    V_SOURCE_ROLE_EXISTS BOOLEAN DEFAULT FALSE;
    V_TARGET_ROLE_EXISTS BOOLEAN DEFAULT FALSE;
BEGIN
    -- Start Logging
    V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Procedure Start'', ''INFO'', ''Starting CLONE_ROLE_PROC procedure.'', :4);';
    EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, P_SERVICENOW_TASK);

    -- Check if Source Role Exists
    SELECT COUNT(*) > 0 INTO V_SOURCE_ROLE_EXISTS FROM INFORMATION_SCHEMA.ROLES WHERE ROLE_NAME = :P_SOURCE_ROLE_NAME AND DELETED_ON IS NULL;

    IF (NOT V_SOURCE_ROLE_EXISTS) THEN
        V_MESSAGE := 'Source role ' || P_SOURCE_ROLE_NAME || ' does not exist.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Check Source Role'', ''FAILURE'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
        RAISE USER_DEFINED_EXCEPTION(V_MESSAGE);
    ELSE
        V_MESSAGE := 'Source role ' || P_SOURCE_ROLE_NAME || ' found.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Check Source Role'', ''SUCCESS'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
    END IF;

    -- Check if Target Role Exists
    SELECT COUNT(*) > 0 INTO V_TARGET_ROLE_EXISTS FROM INFORMATION_SCHEMA.ROLES WHERE ROLE_NAME = :P_TARGET_ROLE_NAME AND DELETED_ON IS NULL;

    IF (V_TARGET_ROLE_EXISTS) THEN
        V_MESSAGE := 'Target role ' || P_TARGET_ROLE_NAME || ' already exists.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Check Target Role'', ''FAILURE'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
        RAISE USER_DEFINED_EXCEPTION(V_MESSAGE);
    ELSE
        V_MESSAGE := 'Target role ' || P_TARGET_ROLE_NAME || ' does not exist, proceeding with creation.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Check Target Role'', ''SUCCESS'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
    END IF;

    -- Create Target Role
    BEGIN
        CREATE ROLE IDENTIFIER(:P_TARGET_ROLE_NAME);
        V_MESSAGE := 'Target role ' || P_TARGET_ROLE_NAME || ' created successfully.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Create Target Role'', ''SUCCESS'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
    EXCEPTION
        WHEN OTHER THEN
            V_MESSAGE := 'Failed to create target role ' || P_TARGET_ROLE_NAME || '. SQLERRM: ' || SQLERRM;
            V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Create Target Role'', ''FAILURE'', :4, :5);';
            EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
            RAISE; 
    END;

    -- Grant Source Role to Target Role
    BEGIN
        GRANT ROLE IDENTIFIER(:P_SOURCE_ROLE_NAME) TO ROLE IDENTIFIER(:P_TARGET_ROLE_NAME);
        V_MESSAGE := 'Granted source role ' || P_SOURCE_ROLE_NAME || ' to target role ' || P_TARGET_ROLE_NAME || '.';
        V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Grant Role'', ''SUCCESS'', :4, :5);';
        EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
    EXCEPTION
        WHEN OTHER THEN
            V_MESSAGE := 'Failed to grant source role ' || P_SOURCE_ROLE_NAME || ' to target role ' || P_TARGET_ROLE_NAME || '. SQLERRM: ' || SQLERRM;
            V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Grant Role'', ''FAILURE'', :4, :5);';
            EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
            RAISE; 
    END;

    -- End Logging
    V_MESSAGE := 'CLONE_ROLE_PROC procedure completed successfully.';
    V_LOG_STATEMENT := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Procedure End'', ''SUCCESS'', :4, :5);';
    EXECUTE IMMEDIATE V_LOG_STATEMENT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);

    RETURN 'SUCCESS';

EXCEPTION
    WHEN USER_DEFINED_EXCEPTION THEN
        RETURN SQLERRM;
    WHEN OTHER THEN
        V_MESSAGE := 'An unexpected error occurred. SQLCODE: ' || SQLCODE || ', SQLERRM: ' || SQLERRM || ', SQLSTATE: ' || SQLSTATE;
        LET LOG_ERROR_STMT VARCHAR := 'INSERT INTO IDENTIFIER(:1) (SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK) VALUES (:2, :3, ''Procedure Exception'', ''FATAL'', :4, :5);';
        TRY
            EXECUTE IMMEDIATE LOG_ERROR_STMT USING (P_LOG_TABLE_NAME, P_SOURCE_ROLE_NAME, P_TARGET_ROLE_NAME, V_MESSAGE, P_SERVICENOW_TASK);
        EXCEPTION
            WHEN OTHER THEN
                NULL; 
        END;
        RETURN V_MESSAGE;
END;
$$;
