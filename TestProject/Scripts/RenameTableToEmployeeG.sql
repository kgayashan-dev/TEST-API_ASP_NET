-- ==========================================================
-- Database: TestDB
-- Script: Rename table dbo.EmployeesG to dbo.EmployeeG
-- ==========================================================

USE TestDB;
GO

IF OBJECT_ID(N'dbo.EmployeesG', N'U') IS NOT NULL
BEGIN
    PRINT 'Renaming table [dbo].[EmployeesG] to [dbo].[EmployeeG]...';
    EXEC sp_rename 'dbo.EmployeesG', 'EmployeeG';
    PRINT 'Table successfully renamed to [dbo].[EmployeeG].';
END
ELSE
BEGIN
    PRINT 'Table [dbo].[EmployeesG] does not exist (it may already be named [dbo].[EmployeeG]).';
END
GO

-- Verification query
SELECT TABLE_SCHEMA, TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('EmployeeG', 'EmployeesG');
GO
