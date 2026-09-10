-- ==========================================================
-- Database: GayashanTest
-- Table: dbo.Users
-- Description: Stores application user accounts and authentication state.
-- ==========================================================

USE GayashanTest;
GO

IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'Users' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.Users
    (
        LoginID                 INT IDENTITY(1,1)   NOT NULL,
        UserName                NVARCHAR(50)        NOT NULL,
        FullName                NVARCHAR(150)       NOT NULL,
        UserTitle               NVARCHAR(50)        NULL,
        DisplayName             NVARCHAR(100)       NULL,
        ContactNumber           NVARCHAR(25)        NULL,
        Email                   NVARCHAR(100)       NOT NULL,
        [Password]              NVARCHAR(255)       NOT NULL,       -- Stores salted & hashed password
        IsLockedOut             BIT                 NOT NULL CONSTRAINT DF_Users_IsLockedOut DEFAULT (0),
        IsLockedPermanently     BIT                 NOT NULL CONSTRAINT DF_Users_IsLockedPermanently DEFAULT (0),
        PermanentlyLockedDate   DATETIME2(7)        NULL,
        LastPasswordChangedDate DATETIME2(7)        NULL,
        SysDate                 DATETIME2(7)        NOT NULL CONSTRAINT DF_Users_SysDate DEFAULT (SYSUTCDATETIME()),
        IsPwdChanged            BIT                 NOT NULL CONSTRAINT DF_Users_IsPwdChanged DEFAULT (0),
        FailedLoginAttemptCount INT                 NOT NULL CONSTRAINT DF_Users_FailedLoginAttemptCount DEFAULT (0),
        LastFailedLoginDate     DATETIME2(7)        NULL,

        -- Constraints
        CONSTRAINT PK_Users PRIMARY KEY CLUSTERED (LoginID ASC),
        CONSTRAINT UQ_Users_UserName UNIQUE NONCLUSTERED (UserName ASC),
        CONSTRAINT UQ_Users_Email UNIQUE NONCLUSTERED (Email ASC)
    );

    -- Additional Indexes for login and lockout lookups
    CREATE NONCLUSTERED INDEX IX_Users_IsLockedOut 
        ON dbo.Users (IsLockedOut, IsLockedPermanently)
        INCLUDE (UserName, Email, FailedLoginAttemptCount);

    PRINT 'Table dbo.Users created successfully.';
END
ELSE
BEGIN
    PRINT 'Table dbo.Users already exists.';
END
GO
