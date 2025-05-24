# Snowflake Role Cloning Solution

## 1. Overview

This solution provides a robust mechanism for cloning an existing Snowflake role to a new target role. The process includes comprehensive logging of all actions, successes, and failures into a designated log table. This is particularly useful for maintaining an audit trail, linking operations to change requests (e.g., ServiceNow tasks), and for troubleshooting.

The core of the solution is a Snowflake stored procedure, `CLONE_ROLE_PROC`, which handles the cloning logic, and a SQL script to create the necessary logging table, `ROLE_CLONE_LOG`.

## 2. Components

The solution consists of two main SQL files:

*   **`create_role_clone_log_table.sql`**: This script creates the `ROLE_CLONE_LOG` table, which is used by the stored procedure to record its operations. The table includes columns for timestamps, procedure name, source and target roles, action performed, status (success/failure), detailed messages, and an optional ServiceNow task identifier.
*   **`clone_role_proc.sql`**: This script creates the stored procedure `CLONE_ROLE_PROC`. This procedure takes a source role name, a target role name, a log table name, and an optional ServiceNow task identifier as input, then attempts to create the target role and grant the source role to it.

## 3. Setup Instructions

Follow these steps to set up and use the role cloning solution in your Snowflake environment:

### Step 1: Create the Log Table

First, you need to create the table where the cloning procedure will log its activities.

1.  Open a Snowflake worksheet.
2.  Load the content of `create_role_clone_log_table.sql`.
3.  Execute the script. This will create the `ROLE_CLONE_LOG` table.

```sql
-- Content of create_role_clone_log_table.sql
CREATE TABLE IF NOT EXISTS ROLE_CLONE_LOG (
    LOG_TIMESTAMP TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    PROCEDURE_NAME VARCHAR DEFAULT 'CLONE_ROLE_PROC',
    SOURCE_ROLE VARCHAR,
    TARGET_ROLE VARCHAR,
    ACTION VARCHAR,
    STATUS VARCHAR,
    MESSAGE VARCHAR,
    SERVICENOW_TASK VARCHAR -- New column for ServiceNow task ID
);
```

**Note:** The default log table name used in the examples is `ROLE_CLONE_LOG`. The stored procedure's `P_LOG_TABLE_NAME` parameter allows you to specify a different table name if needed, but ensure its structure is compatible (including the `SERVICENOW_TASK` column).

### Step 2: Create the Stored Procedure

Next, deploy the stored procedure that performs the role cloning.

1.  Open a new Snowflake worksheet.
2.  Load the content of `clone_role_proc.sql`.
3.  Execute the script. This will create or replace the `CLONE_ROLE_PROC` stored procedure with the updated signature.

Make sure you have the necessary permissions (e.g., `CREATE PROCEDURE`) in the database/schema where you intend to create this procedure.

## 4. Procedure Parameters

The `CLONE_ROLE_PROC` stored procedure accepts the following parameters:

*   **`P_SOURCE_ROLE_NAME VARCHAR`**: The name of the existing Snowflake role that you want to clone. This role must exist for the procedure to succeed.
*   **`P_TARGET_ROLE_NAME VARCHAR`**: The desired name for the new role that will be created as a clone. This role must *not* already exist.
*   **`P_LOG_TABLE_NAME VARCHAR`**: The name of the table to be used for logging. This table must exist and be writable by the procedure (e.g., `ROLE_CLONE_LOG` created in Step 1).
*   **`P_SERVICENOW_TASK VARCHAR`**: The ServiceNow task number or identifier related to this role cloning operation (e.g., 'TASK12345', 'CHG000789'). This will be recorded in the `SERVICENOW_TASK` column of the log table. This parameter is optional in the sense that you can pass `NULL` or an empty string if not applicable.

## 5. Usage Example (SQL)

Here's how you can call the `CLONE_ROLE_PROC` stored procedure and check its logs.

**Prerequisites for examples:**
*   Assume `ROLE_CLONE_LOG` table has been created (with the new `SERVICENOW_TASK` column).
*   Assume a role named `EXISTING_SOURCE_ROLE` exists.
*   Assume a role named `EXISTING_TARGET_ROLE` also exists for the failure scenario.

```sql
-- Example 1: Successful role clone
-- Action: Clones 'EXISTING_SOURCE_ROLE' to 'NEW_TARGET_ROLE', associated with TASK12345.
-- Expected: 'NEW_TARGET_ROLE' is created and 'EXISTING_SOURCE_ROLE' is granted to it.
--           Procedure returns 'SUCCESS'.
CALL CLONE_ROLE_PROC('EXISTING_SOURCE_ROLE', 'NEW_TARGET_ROLE', 'ROLE_CLONE_LOG', 'TASK12345');

-- Example 2: Attempt to clone to an already existing target role
-- Action: Attempts to clone 'EXISTING_SOURCE_ROLE' to 'EXISTING_TARGET_ROLE', associated with TASK12346.
-- Expected: Procedure fails because 'EXISTING_TARGET_ROLE' already exists.
--           Procedure returns an error message like "Target role EXISTING_TARGET_ROLE already exists."
CALL CLONE_ROLE_PROC('EXISTING_SOURCE_ROLE', 'EXISTING_TARGET_ROLE', 'ROLE_CLONE_LOG', 'TASK12346');

-- Example 3: Attempt to clone from a non-existent source role
-- Action: Attempts to clone 'NON_EXISTENT_SOURCE_ROLE' to 'ANOTHER_NEW_TARGET_ROLE', associated with TASK12347.
-- Expected: Procedure fails because 'NON_EXISTENT_SOURCE_ROLE' does not exist.
--           Procedure returns an error message like "Source role NON_EXISTENT_SOURCE_ROLE does not exist."
CALL CLONE_ROLE_PROC('NON_EXISTENT_SOURCE_ROLE', 'ANOTHER_NEW_TARGET_ROLE', 'ROLE_CLONE_LOG', 'TASK12347');

-- Example 4: Using a different log table and no specific ServiceNow task
-- (Ensure 'CUSTOM_LOG_TABLE' exists, is compatible, and P_SERVICENOW_TASK can be NULL or empty string)
CALL CLONE_ROLE_PROC('EXISTING_SOURCE_ROLE', 'YET_ANOTHER_TARGET_ROLE', 'CUSTOM_LOG_TABLE', NULL);
```

### Querying the Log Table

To review the actions performed by the procedure, including any errors and associated ServiceNow tasks, query the log table:

```sql
-- View all logs, most recent first (includes the new SERVICENOW_TASK column)
SELECT * FROM ROLE_CLONE_LOG ORDER BY LOG_TIMESTAMP DESC;

-- View specific columns for logs related to 'NEW_TARGET_ROLE', including SERVICENOW_TASK
SELECT LOG_TIMESTAMP, SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK
FROM ROLE_CLONE_LOG
WHERE TARGET_ROLE = 'NEW_TARGET_ROLE'
ORDER BY LOG_TIMESTAMP DESC;

-- View only error messages, including SERVICENOW_TASK
SELECT LOG_TIMESTAMP, SOURCE_ROLE, TARGET_ROLE, ACTION, STATUS, MESSAGE, SERVICENOW_TASK
FROM ROLE_CLONE_LOG
WHERE STATUS != 'SUCCESS' AND STATUS != 'INFO'
ORDER BY LOG_TIMESTAMP DESC;
```

## 6. Error Handling Notes

*   The `CLONE_ROLE_PROC` procedure is designed to return a simple `'SUCCESS'` message upon successful completion.
*   In case of an error (e.g., source role not found, target role already exists, insufficient permissions), the procedure will return an error message string.
*   Detailed information about each step, including the specifics of any errors encountered (SQLCODE, SQLERRM, SQLSTATE for unexpected errors) and the `SERVICENOW_TASK` identifier, is logged to the specified log table (e.g., `ROLE_CLONE_LOG`). Always consult this table for comprehensive troubleshooting.
*   The procedure uses `EXECUTE AS CALLER`, meaning it runs with the privileges of the user calling it. Ensure the calling role has permissions to:
    *   Read from the source role.
    *   Create new roles.
    *   Grant roles.
    *   Write to the log table.

---
End of UsageGuide.md
---
```
