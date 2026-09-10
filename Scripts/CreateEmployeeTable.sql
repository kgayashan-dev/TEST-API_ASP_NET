-- ==========================================================
-- Script: Create Employee Table
-- Compatible with: Microsoft SQL Server / Azure SQL
-- ==========================================================

IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Employees')
BEGIN
    CREATE TABLE Employees (
        -- Primary Key
        EmployeeId          INT IDENTITY(1, 1) PRIMARY KEY,

        -- Personal & Contact Information
        FirstName           NVARCHAR(50)        NOT NULL,
        LastName            NVARCHAR(50)        NOT NULL,
        Email               NVARCHAR(256)       NOT NULL,
        PhoneNumber         NVARCHAR(25)        NULL,
        DateOfBirth         DATE                NULL,

        -- Employment Details
        EpfNo               NVARCHAR(30)        NULL,
        JobTitle            NVARCHAR(100)       NOT NULL,
        Department          NVARCHAR(100)       NOT NULL,
        HireDate            DATE                NOT NULL,
        TerminationDate     DATE                NULL,
        Salary              DECIMAL(18, 2)      NOT NULL,
        Status              NVARCHAR(20)        NOT NULL DEFAULT 'Active', -- 'Active', 'OnLeave', 'Terminated'

        -- Organizational Hierarchy (Self-referencing Foreign Key)
        ManagerId           INT                 NULL,

        -- Audit / Tracking Metadata
        CreatedAt           DATETIMEOFFSET      NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        UpdatedAt           DATETIMEOFFSET      NULL,
        IsDeleted           BIT                 NOT NULL DEFAULT 0,

        -- Table Constraints
        CONSTRAINT UQ_Employees_Email UNIQUE (Email),
        CONSTRAINT CHK_Employees_Salary CHECK (Salary >= 0),
        CONSTRAINT CHK_Employees_Status CHECK (Status IN ('Active', 'OnLeave', 'Terminated')),
        CONSTRAINT FK_Employees_Manager FOREIGN KEY (ManagerId) 
            REFERENCES Employees(EmployeeId)
    );

    -- Useful Indexes for Query Performance
    CREATE NONCLUSTERED INDEX IX_Employees_Department ON Employees(Department);
    CREATE NONCLUSTERED INDEX IX_Employees_ManagerId ON Employees(ManagerId);
    CREATE NONCLUSTERED INDEX IX_Employees_Status ON Employees(Status);
    CREATE UNIQUE NONCLUSTERED INDEX UQ_Employees_EpfNo ON Employees(EpfNo) WHERE EpfNo IS NOT NULL;
END
GO

-- ==========================================================
-- Sample Seed Data
-- ==========================================================
IF NOT EXISTS (SELECT 1 FROM Employees)
BEGIN
    INSERT INTO Employees (FirstName, LastName, Email, PhoneNumber, EpfNo, JobTitle, Department, HireDate, Salary, Status, ManagerId)
    VALUES 
    (N'Jane', N'Doe', N'jane.doe@example.com', N'+1-555-0100', N'EPF-00101', N'Engineering Director', N'Engineering', '2022-01-15', 150000.00, 'Active', NULL);

    DECLARE @ManagerId INT = SCOPE_IDENTITY();

    INSERT INTO Employees (FirstName, LastName, Email, PhoneNumber, EpfNo, JobTitle, Department, HireDate, Salary, Status, ManagerId)
    VALUES 
    (N'John', N'Smith', N'john.smith@example.com', N'+1-555-0101', N'EPF-00102', N'Senior Software Engineer', N'Engineering', '2023-03-01', 115000.00, 'Active', @ManagerId),
    (N'Alice', N'Johnson', N'alice.j@example.com', N'+1-555-0102', N'EPF-00103', N'QA Engineer', N'Engineering', '2023-06-15', 85000.00, 'Active', @ManagerId);
END
GO

-- ==========================================================
-- Migration for existing TestDB.dbo.EmployeeH table:
-- Run this if you are using the existing EmployeeH table in TestDB
-- ==========================================================
USE TestDB;
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.columns 
    WHERE object_id = OBJECT_ID('dbo.EmployeeH') AND name = 'EpfNo'
)
BEGIN
    ALTER TABLE dbo.EmployeeH
    ADD EpfNo NVARCHAR(30) NULL;

    CREATE UNIQUE NONCLUSTERED INDEX UQ_EmployeeH_EpfNo 
    ON dbo.EmployeeH(EpfNo) 
    WHERE EpfNo IS NOT NULL;
END
GO

