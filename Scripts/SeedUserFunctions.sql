-- ==========================================================
-- Database: GayashanTest
-- Script: SeedUserFunctions.sql
-- Description: Populates realistic sample function/permission grants
--              into dbo.UserFunctions for active users.
--              Safe to run repeatedly (Idempotent).
-- ==========================================================

USE GayashanTest;
GO

SET NOCOUNT ON;
PRINT '==========================================================';
PRINT 'Starting User Functions Seeding for GayashanTest...';
PRINT '==========================================================';

------------------------------------------------------------
-- Staging Table for Sample Role-to-Function Assignments
------------------------------------------------------------
DECLARE @UserFunctionMapping TABLE
(
    UserName     NVARCHAR(50),
    FunctionCode VARCHAR(50),
    IsGranted    BIT,
    AssignedBy   NVARCHAR(100)
);

INSERT INTO @UserFunctionMapping (UserName, FunctionCode, IsGranted, AssignedBy)
VALUES
    -- Admin / Head of Engineering: Full Access across all modules
    ('admin.gayashans23', 'EMP_VIEW',    1, 'system-admin'),
    ('admin.gayashans23', 'EMP_CREATE',  1, 'system-admin'),
    ('admin.gayashans23', 'EMP_UPDATE',  1, 'system-admin'),
    ('admin.gayashans23', 'EMP_DELETE',  1, 'system-admin'),
    ('admin.gayashans23', 'USER_VIEW',   1, 'system-admin'),
    ('admin.gayashans23', 'USER_CREATE', 1, 'system-admin'),
    ('admin.gayashans23', 'USER_UPDATE', 1, 'system-admin'),
    ('admin.gayashans23', 'USER_LOCK',   1, 'system-admin'),

    -- Also support fallback if username is 'admin.gayashan'
    ('admin.gayashan',    'EMP_VIEW',    1, 'system-admin'),
    ('admin.gayashan',    'EMP_CREATE',  1, 'system-admin'),
    ('admin.gayashan',    'EMP_UPDATE',  1, 'system-admin'),
    ('admin.gayashan',    'EMP_DELETE',  1, 'system-admin'),
    ('admin.gayashan',    'USER_VIEW',   1, 'system-admin'),
    ('admin.gayashan',    'USER_CREATE', 1, 'system-admin'),
    ('admin.gayashan',    'USER_UPDATE', 1, 'system-admin'),
    ('admin.gayashan',    'USER_LOCK',   1, 'system-admin'),

    -- Senior HR Director: Employee Management Access
    ('sarah.jenkins',     'EMP_VIEW',    1, 'admin.gayashan'),
    ('sarah.jenkins',     'EMP_CREATE',  1, 'admin.gayashan'),
    ('sarah.jenkins',     'EMP_UPDATE',  1, 'admin.gayashan'),
    ('sarah.jenkins',     'USER_VIEW',   1, 'admin.gayashan'),

    -- Lead Financial Controller: View Only
    ('michael.chang',     'EMP_VIEW',    1, 'admin.gayashan'),

    -- Senior Full Stack Engineer: Employee Management
    ('anura.kumara',      'EMP_VIEW',    1, 'admin.gayashan'),
    ('anura.kumara',      'EMP_CREATE',  1, 'admin.gayashan'),
    ('anura.kumara',      'EMP_UPDATE',  1, 'admin.gayashan'),

    -- QA Automation Lead: View Permissions
    ('priya.nair',        'EMP_VIEW',    1, 'admin.gayashan'),
    ('priya.nair',        'USER_VIEW',   1, 'admin.gayashan'),

    -- DevOps & Cloud Architect: User Management & View
    ('kevin.taylor',      'EMP_VIEW',    1, 'admin.gayashan'),
    ('kevin.taylor',      'USER_VIEW',   1, 'admin.gayashan'),
    ('kevin.taylor',      'USER_LOCK',   1, 'admin.gayashan'),

    -- Senior Software Engineer: View and Create Employees
    ('kasun.perera',      'EMP_VIEW',    1, 'admin.gayashan'),
    ('kasun.perera',      'EMP_CREATE',  1, 'admin.gayashan');

------------------------------------------------------------
-- Insert Grants dynamically mapping LoginID and FunctionID
------------------------------------------------------------
DECLARE 
    @uName NVARCHAR(50), 
    @fCode VARCHAR(50), 
    @granted BIT, 
    @by NVARCHAR(100),
    @loginId INT,
    @funcId INT;

DECLARE func_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT UserName, FunctionCode, IsGranted, AssignedBy
FROM @UserFunctionMapping;

OPEN func_cursor;
FETCH NEXT FROM func_cursor INTO @uName, @fCode, @granted, @by;

WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @loginId = LoginID FROM dbo.Users WHERE UserName = @uName;
    SELECT @funcId  = FunctionID FROM dbo.AppFunctions WHERE FunctionCode = @fCode;

    IF @loginId IS NOT NULL AND @funcId IS NOT NULL
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM dbo.UserFunctions WHERE LoginID = @loginId AND FunctionID = @funcId)
        BEGIN
            INSERT INTO dbo.UserFunctions (LoginID, FunctionID, IsGranted, AssignedBy, AssignedDate, SysDate)
            VALUES (@loginId, @funcId, @granted, @by, SYSUTCDATETIME(), SYSUTCDATETIME());

            PRINT '  + Granted [' + @fCode + '] to user [' + @uName + '] (LoginID: ' + CAST(@loginId AS VARCHAR(10)) + ')';
        END
        ELSE
        BEGIN
            PRINT '  . Grant already exists for [' + @uName + '] -> [' + @fCode + ']';
        END
    END

    FETCH NEXT FROM func_cursor INTO @uName, @fCode, @granted, @by;
END;

CLOSE func_cursor;
DEALLOCATE func_cursor;

PRINT '==========================================================';
PRINT 'User Functions Seeding Completed!';
PRINT '==========================================================';
GO
