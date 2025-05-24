-- Test script for CLONE_ROLE_PROC and ROLE_CLONE_LOG
-- Prerequisites:
-- 1. ROLE_CLONE_LOG table must exist (created by create_role_clone_log_table.sql, including SERVICENOW_TASK column).
-- 2. CLONE_ROLE_PROC stored procedure must exist (created by clone_role_proc.sql, including P_SERVICENOW_TASK parameter).
-- This script should be run in a Snowflake worksheet.

-- Use a specific database and schema if needed, e.g.:
-- USE DATABASE YOUR_DATABASE;
-- USE SCHEMA YOUR_SCHEMA;

SELECT 'Starting Test Script for CLONE_ROLE_PROC (with ServiceNow Task)...' AS "INFO";

-- ====================================================================================
-- 0. Initial Setup
-- ====================================================================================
SELECT 'Step 0: Initial Setup - Creating test roles and cleaning up...' AS "INFO";

-- Drop roles if they exist from previous partial runs (ignoring errors if they don't exist)
BEGIN
    DROP ROLE IF EXISTS TEST_TARGET_ROLE_SUCCESS;
    DROP ROLE IF EXISTS TEST_TARGET_ROLE_ALREADY_EXISTS;
    DROP ROLE IF EXISTS TEST_TARGET_ROLE_NO_SOURCE;
    DROP ROLE IF EXISTS TEST_SOURCE_ROLE;
EXCEPTION
    WHEN OTHER THEN
        SELECT 'Minor error during initial cleanup (e.g., role not found), proceeding...' AS "WARNING";
END;

-- Create a dummy source role
CREATE ROLE TEST_SOURCE_ROLE;
COMMENT ON ROLE TEST_SOURCE_ROLE IS 'Test source role for CLONE_ROLE_PROC validation';
SELECT 'TEST_SOURCE_ROLE created.' AS "SETUP_INFO";

SELECT 'Initial cleanup and setup complete.' AS "INFO";

-- ====================================================================================
-- Test Case 1: Successful Role Clone
-- ====================================================================================
SELECT 'Test Case 1: Successful Role Clone' AS "TEST_CASE";
SET TEST_SN_TASK_001 = 'SN_TASK_CLONE_SUCCESS';
SELECT 'Calling CLONE_ROLE_PROC(''TEST_SOURCE_ROLE'', ''TEST_TARGET_ROLE_SUCCESS'', ''ROLE_CLONE_LOG'', ''' || $TEST_SN_TASK_001 || ''')...' AS "ACTION";

CALL CLONE_ROLE_PROC('TEST_SOURCE_ROLE', 'TEST_TARGET_ROLE_SUCCESS', 'ROLE_CLONE_LOG', $TEST_SN_TASK_001);
-- Expected: Procedure returns 'SUCCESS'. (Snowflake worksheets will show the result of the CALL)

SELECT 'Verifying TEST_TARGET_ROLE_SUCCESS creation...' AS "VERIFICATION";
SHOW ROLES LIKE 'TEST_TARGET_ROLE_SUCCESS';
-- Expected: One row showing TEST_TARGET_ROLE_SUCCESS.

SELECT 'Verifying grant of TEST_SOURCE_ROLE to TEST_TARGET_ROLE_SUCCESS...' AS "VERIFICATION";
SHOW GRANTS TO ROLE TEST_TARGET_ROLE_SUCCESS;
-- Expected: Should list TEST_SOURCE_ROLE.

SELECT 'Querying ROLE_CLONE_LOG for successful clone operations (TEST_SOURCE_ROLE -> TEST_TARGET_ROLE_SUCCESS, Task: ' || $TEST_SN_TASK_001 || ')...' AS "LOG_VERIFICATION";
SELECT LOG_TIMESTAMP, ACTION, STATUS, MESSAGE, SOURCE_ROLE, TARGET_ROLE, SERVICENOW_TASK, PROCEDURE_NAME
FROM ROLE_CLONE_LOG
WHERE SOURCE_ROLE = 'TEST_SOURCE_ROLE' AND TARGET_ROLE = 'TEST_TARGET_ROLE_SUCCESS' AND SERVICENOW_TASK = $TEST_SN_TASK_001
ORDER BY LOG_TIMESTAMP DESC;
-- Expected: Entries for 'Procedure Start', ..., 'Procedure End' (SUCCESS), all with SERVICENOW_TASK = $TEST_SN_TASK_001.

-- ====================================================================================
-- Test Case 2: Target Role Already Exists
-- ====================================================================================
SELECT 'Test Case 2: Target Role Already Exists' AS "TEST_CASE";
SET TEST_SN_TASK_002 = 'SN_TASK_TARGET_EXISTS';

SELECT 'Pre-creating TEST_TARGET_ROLE_ALREADY_EXISTS...' AS "SETUP_ACTION";
CREATE ROLE TEST_TARGET_ROLE_ALREADY_EXISTS;
COMMENT ON ROLE TEST_TARGET_ROLE_ALREADY_EXISTS IS 'Test target role for "already exists" scenario';

SELECT 'Calling CLONE_ROLE_PROC(''TEST_SOURCE_ROLE'', ''TEST_TARGET_ROLE_ALREADY_EXISTS'', ''ROLE_CLONE_LOG'', ''' || $TEST_SN_TASK_002 || ''')...' AS "ACTION";
CALL CLONE_ROLE_PROC('TEST_SOURCE_ROLE', 'TEST_TARGET_ROLE_ALREADY_EXISTS', 'ROLE_CLONE_LOG', $TEST_SN_TASK_002);
-- Expected: Procedure returns an error message like "Target role TEST_TARGET_ROLE_ALREADY_EXISTS already exists."

SELECT 'Querying ROLE_CLONE_LOG for "Target Role Already Exists" failure (Task: ' || $TEST_SN_TASK_002 || ')...' AS "LOG_VERIFICATION";
SELECT LOG_TIMESTAMP, ACTION, STATUS, MESSAGE, SOURCE_ROLE, TARGET_ROLE, SERVICENOW_TASK, PROCEDURE_NAME
FROM ROLE_CLONE_LOG
WHERE SOURCE_ROLE = 'TEST_SOURCE_ROLE' AND TARGET_ROLE = 'TEST_TARGET_ROLE_ALREADY_EXISTS' AND SERVICENOW_TASK = $TEST_SN_TASK_002
ORDER BY LOG_TIMESTAMP DESC;
-- Expected: Entries showing 'Procedure Start', 'Check Source Role' (SUCCESS), 'Check Target Role' (FAILURE), all with SERVICENOW_TASK = $TEST_SN_TASK_002.

-- ====================================================================================
-- Test Case 3: Source Role Does Not Exist
-- ====================================================================================
SELECT 'Test Case 3: Source Role Does Not Exist' AS "TEST_CASE";
SET TEST_SN_TASK_003 = 'SN_TASK_SOURCE_MISSING';
SELECT 'Calling CLONE_ROLE_PROC(''NON_EXISTENT_TEST_SOURCE_ROLE'', ''TEST_TARGET_ROLE_NO_SOURCE'', ''ROLE_CLONE_LOG'', ''' || $TEST_SN_TASK_003 || ''')...' AS "ACTION";

CALL CLONE_ROLE_PROC('NON_EXISTENT_TEST_SOURCE_ROLE', 'TEST_TARGET_ROLE_NO_SOURCE', 'ROLE_CLONE_LOG', $TEST_SN_TASK_003);
-- Expected: Procedure returns an error message like "Source role NON_EXISTENT_TEST_SOURCE_ROLE does not exist."

SELECT 'Verifying TEST_TARGET_ROLE_NO_SOURCE was not created...' AS "VERIFICATION";
SHOW ROLES LIKE 'TEST_TARGET_ROLE_NO_SOURCE';
-- Expected: Zero rows.

SELECT 'Querying ROLE_CLONE_LOG for "Source Role Does Not Exist" failure (Task: ' || $TEST_SN_TASK_003 || ')...' AS "LOG_VERIFICATION";
SELECT LOG_TIMESTAMP, ACTION, STATUS, MESSAGE, SOURCE_ROLE, TARGET_ROLE, SERVICENOW_TASK, PROCEDURE_NAME
FROM ROLE_CLONE_LOG
WHERE SOURCE_ROLE = 'NON_EXISTENT_TEST_SOURCE_ROLE' AND TARGET_ROLE = 'TEST_TARGET_ROLE_NO_SOURCE' AND SERVICENOW_TASK = $TEST_SN_TASK_003
ORDER BY LOG_TIMESTAMP DESC;
-- Expected: Entries showing 'Procedure Start', 'Check Source Role' (FAILURE), all with SERVICENOW_TASK = $TEST_SN_TASK_003.

-- ====================================================================================
-- 5. Cleanup
-- ====================================================================================
SELECT 'Step 5: Cleanup - Dropping test roles...' AS "INFO";

DROP ROLE IF EXISTS TEST_TARGET_ROLE_SUCCESS;
SELECT 'Dropped TEST_TARGET_ROLE_SUCCESS (if existed).' AS "CLEANUP_INFO";

DROP ROLE IF EXISTS TEST_TARGET_ROLE_ALREADY_EXISTS;
SELECT 'Dropped TEST_TARGET_ROLE_ALREADY_EXISTS (if existed).' AS "CLEANUP_INFO";

-- TEST_TARGET_ROLE_NO_SOURCE should not have been created, but drop just in case.
DROP ROLE IF EXISTS TEST_TARGET_ROLE_NO_SOURCE;
SELECT 'Dropped TEST_TARGET_ROLE_NO_SOURCE (if existed).' AS "CLEANUP_INFO";

DROP ROLE IF EXISTS TEST_SOURCE_ROLE;
SELECT 'Dropped TEST_SOURCE_ROLE (if existed).' AS "CLEANUP_INFO";

SELECT 'Cleanup complete.' AS "INFO";
SELECT 'Test script finished. Please review the ROLE_CLONE_LOG table for detailed logs of all operations.' AS "FINAL_MESSAGE";
SELECT 'Consider truncating or managing ROLE_CLONE_LOG entries as per your requirements after review.' AS "LOG_MANAGEMENT_NOTE";

-- Example: To clear the log table after testing (optional)
-- TRUNCATE TABLE ROLE_CLONE_LOG;
-- SELECT 'ROLE_CLONE_LOG table truncated.' AS "INFO";
```
