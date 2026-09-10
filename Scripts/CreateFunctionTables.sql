-- ==========================================================
-- Database: GayashanTest
-- Script: CreateFunctionTables.sql
-- Description: Creates tables to store application functions/permissions
--              and user-specific function assignments.
-- ==========================================================

USE GayashanTest;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

------------------------------------------------------------
-- 1. Table: dbo.AppFunctions (Stores system functions / permissions)
------------------------------------------------------------
IF OBJECT_ID('dbo.AppFunctions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.AppFunctions
    (
        FunctionID    INT IDENTITY(1,1) NOT NULL,
        FunctionCode  VARCHAR(50)       NOT NULL,
        FunctionName  NVARCHAR(100)     NOT NULL,
        Module        NVARCHAR(50)      NOT NULL,
        [Description] NVARCHAR(250)     NULL,
        IsActive      BIT               NOT NULL CONSTRAINT DF_AppFunctions_IsActive DEFAULT (1),
        CreatedBy     NVARCHAR(100)     NULL,
        SysDate       DATETIME2(7)      NOT NULL CONSTRAINT DF_AppFunctions_SysDate DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_AppFunctions PRIMARY KEY CLUSTERED (FunctionID),
        CONSTRAINT UQ_AppFunctions_FunctionCode UNIQUE NONCLUSTERED (FunctionCode)
    );

    PRINT 'Table [dbo].[AppFunctions] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[AppFunctions] already exists.';
END
GO

------------------------------------------------------------
-- 2. Table: dbo.UserFunctions (Stores functions assigned to each user)
------------------------------------------------------------
IF OBJECT_ID('dbo.UserFunctions', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.UserFunctions
    (
        UserFunctionID INT IDENTITY(1,1) NOT NULL,
        LoginID        INT               NOT NULL,
        FunctionID     INT               NOT NULL,
        IsGranted      BIT               NOT NULL CONSTRAINT DF_UserFunctions_IsGranted DEFAULT (1),
        AssignedBy     NVARCHAR(100)     NULL,
        AssignedDate   DATETIME2(7)      NOT NULL CONSTRAINT DF_UserFunctions_AssignedDate DEFAULT (SYSUTCDATETIME()),
        SysDate        DATETIME2(7)      NOT NULL CONSTRAINT DF_UserFunctions_SysDate DEFAULT (SYSUTCDATETIME()),

        CONSTRAINT PK_UserFunctions PRIMARY KEY CLUSTERED (UserFunctionID),
        CONSTRAINT FK_UserFunctions_Users FOREIGN KEY (LoginID) 
            REFERENCES dbo.Users (LoginID) ON DELETE CASCADE,
        CONSTRAINT FK_UserFunctions_AppFunctions FOREIGN KEY (FunctionID) 
            REFERENCES dbo.AppFunctions (FunctionID) ON DELETE CASCADE,
        CONSTRAINT UQ_UserFunctions_Login_Function UNIQUE NONCLUSTERED (LoginID, FunctionID)
    );

    -- Index for fast user permission resolution during authorization
    CREATE NONCLUSTERED INDEX IX_UserFunctions_LoginID_IsGranted
        ON dbo.UserFunctions (LoginID, IsGranted)
        INCLUDE (FunctionID);

    PRINT 'Table [dbo].[UserFunctions] created successfully.';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[UserFunctions] already exists.';
END
GO

------------------------------------------------------------
-- 3. Synonym for convenience (allows querying dbo.Functions)
------------------------------------------------------------
IF OBJECT_ID('dbo.Functions', 'SN') IS NULL AND OBJECT_ID('dbo.Functions', 'U') IS NULL
BEGIN
    CREATE SYNONYM dbo.Functions FOR dbo.AppFunctions;
    PRINT 'Synonym [dbo].[Functions] created pointing to [dbo].[AppFunctions].';
END
GO

------------------------------------------------------------
-- 4. Initial Seed Data (Core Application Functions)
------------------------------------------------------------
IF EXISTS (SELECT 1 FROM dbo.AppFunctions)
BEGIN
    PRINT 'AppFunctions table already contains data. Skipping seed.';
END
ELSE
BEGIN
    INSERT INTO dbo.AppFunctions (FunctionCode, FunctionName, Module, [Description], CreatedBy)
    VALUES
        ('EMP_VIEW',    'View Employees',         'Employee', 'Allows viewing employee lists and details', 'system'),
        ('EMP_CREATE',  'Create Employee',        'Employee', 'Allows creating new employee records',       'system'),
        ('EMP_UPDATE',  'Update Employee',        'Employee', 'Allows updating existing employee records',   'system'),
        ('EMP_DELETE',  'Delete Employee',        'Employee', 'Allows deactivating or deleting employees',   'system'),
        ('USER_VIEW',   'View Users',             'Admin',    'Allows viewing user lists and accounts',      'system'),
        ('USER_CREATE', 'Create User',            'Admin',    'Allows provisioning new user logins',         'system'),
        ('USER_UPDATE', 'Update User',            'Admin',    'Allows updating user profile and credentials', 'system'),
        ('USER_LOCK',   'Lock / Unlock User',     'Admin',    'Allows locking or unlocking user accounts',   'system');

    PRINT 'Initial application functions seeded successfully.';
END
GO
