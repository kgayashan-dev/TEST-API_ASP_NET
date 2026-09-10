-- ==========================================================
-- Database: GayashanTest
-- Script: Create Table [dbo].[AuditTrail]
-- Description: Captures system-wide audit logs, data changes,
--              user actions, and security events.
-- ==========================================================

USE GayashanTest;
GO

IF OBJECT_ID(N'dbo.AuditTrail', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.AuditTrail (
        -- Primary Key
        AuditId             BIGINT IDENTITY(1, 1) PRIMARY KEY,

        -- Target Entity Information
        TableName           NVARCHAR(100)       NOT NULL,                    -- e.g. 'Employee'
        RecordId            NVARCHAR(100)       NOT NULL,                    -- Primary Key of audited record (e.g. EmployeeId)
        ActionType          VARCHAR(20)         NOT NULL,                    -- 'INSERT', 'UPDATE', 'DELETE', 'VIEW'
        
        -- State & Delta Tracking (JSON Format)
        OldValues           NVARCHAR(MAX)       NULL,                        -- State before change (JSON)
        NewValues           NVARCHAR(MAX)       NULL,                        -- State after change (JSON)
        AffectedColumns     NVARCHAR(MAX)       NULL,                        -- Comma-separated list of modified columns

        -- Context & Module Information
        Module              NVARCHAR(100)       NULL,                        -- Module/Area (e.g. 'Payroll', 'HR')
        Narration           NVARCHAR(MAX)       NULL,                        -- Human-readable description / reason

        -- Actor Information
        UserId              NVARCHAR(100)       NULL,                        -- User identifier (username, email, or GUID)
        UserRole            NVARCHAR(50)        NULL,                        -- Role at the time of change
        
        -- Network & Client Diagnostics
        IPAddress           VARCHAR(50)         NULL,                        -- Client IPv4 / IPv6 address
        UserAgent           NVARCHAR(255)       NULL,                        -- Browser or client application details

        -- Timestamp
        TimestampUtc        DATETIME2(7)        NOT NULL DEFAULT SYSUTCDATETIME(),

        -- Constraints
        CONSTRAINT CHK_AuditTrail_ActionType CHECK (ActionType IN ('INSERT', 'UPDATE', 'DELETE', 'VIEW', 'LOGIN', 'LOGOUT', 'EXECUTE'))
    );

    -- Indexes for fast query and reporting performance
    CREATE NONCLUSTERED INDEX IX_AuditTrail_Table_Record 
        ON dbo.AuditTrail(TableName, RecordId);

    CREATE NONCLUSTERED INDEX IX_AuditTrail_TimestampUtc 
        ON dbo.AuditTrail(TimestampUtc DESC);

    CREATE NONCLUSTERED INDEX IX_AuditTrail_UserId 
        ON dbo.AuditTrail(UserId);

    CREATE NONCLUSTERED INDEX IX_AuditTrail_ActionType 
        ON dbo.AuditTrail(ActionType);

    PRINT 'Table [dbo].[AuditTrail] created successfully in GayashanTest.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[AuditTrail] already exists in GayashanTest.';
END
GO
