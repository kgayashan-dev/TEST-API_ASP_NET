-- ==========================================================
-- Database: TestDB
-- Object: Stored Procedure [dbo].[usp_UpsertEmployeeG]
-- Description: Inserts a new employee or updates an existing
--              employee in [dbo].[EmployeeG].
-- ==========================================================

USE TestDB;
GO

-- 1. Ensure Table [dbo].[EmployeeG] exists
IF OBJECT_ID(N'dbo.EmployeeG', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.EmployeeG (
        EmployeeId          INT IDENTITY(1, 1) PRIMARY KEY,
        FirstName           NVARCHAR(50)        NOT NULL,
        LastName            NVARCHAR(50)        NOT NULL,
        Email               NVARCHAR(256)       NOT NULL,
        PhoneNumber         NVARCHAR(25)        NULL,
        DateOfBirth         DATE                NULL,
        EpfNo               NVARCHAR(30)        NULL,
        JobTitle            NVARCHAR(100)       NOT NULL,
        Department          NVARCHAR(100)       NOT NULL,
        HireDate            DATE                NOT NULL,
        TerminationDate     DATE                NULL,
        Salary              DECIMAL(18, 2)      NOT NULL,
        Status              NVARCHAR(20)        NOT NULL DEFAULT 'Active', -- 'Active', 'OnLeave', 'Terminated'
        ManagerId           INT                 NULL,
        CreatedAt           DATETIMEOFFSET      NOT NULL DEFAULT SYSDATETIMEOFFSET(),
        UpdatedAt           DATETIMEOFFSET      NULL,
        IsDeleted           BIT                 NOT NULL DEFAULT 0,

        CONSTRAINT UQ_EmployeeG_Email UNIQUE (Email),
        CONSTRAINT CHK_EmployeeG_Salary CHECK (Salary >= 0),
        CONSTRAINT CHK_EmployeeG_Status CHECK (Status IN ('Active', 'OnLeave', 'Terminated')),
        CONSTRAINT FK_EmployeeG_Manager FOREIGN KEY (ManagerId) REFERENCES dbo.EmployeeG(EmployeeId)
    );

    CREATE UNIQUE NONCLUSTERED INDEX UQ_EmployeeG_EpfNo 
        ON dbo.EmployeeG(EpfNo) 
        WHERE EpfNo IS NOT NULL;

    CREATE NONCLUSTERED INDEX IX_EmployeeG_Department ON dbo.EmployeeG(Department);
    CREATE NONCLUSTERED INDEX IX_EmployeeG_Status ON dbo.EmployeeG(Status);
END
GO

-- 2. Create or Alter Stored Procedure
CREATE OR ALTER PROCEDURE dbo.usp_UpsertEmployeeG
    @EmployeeId         INT = NULL OUTPUT,       -- Pass NULL or <= 0 to INSERT, or existing ID to UPDATE
    @FirstName          NVARCHAR(50),
    @LastName           NVARCHAR(50),
    @Email              NVARCHAR(256),
    @PhoneNumber        NVARCHAR(25)   = NULL,
    @DateOfBirth        DATE           = NULL,
    @EpfNo              NVARCHAR(30)   = NULL,
    @JobTitle           NVARCHAR(100),
    @Department         NVARCHAR(100),
    @HireDate           DATE,
    @TerminationDate    DATE           = NULL,
    @Salary             DECIMAL(18, 2),
    @Status             NVARCHAR(20)   = 'Active',
    @ManagerId          INT            = NULL,
    @IsDeleted          BIT            = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- Data validation: Normalize strings
        SET @FirstName = LTRIM(RTRIM(@FirstName));
        SET @LastName  = LTRIM(RTRIM(@LastName));
        SET @Email     = LOWER(LTRIM(RTRIM(@Email)));
        SET @EpfNo     = NULLIF(LTRIM(RTRIM(@EpfNo)), '');
        SET @Status    = ISNULL(NULLIF(LTRIM(RTRIM(@Status)), ''), 'Active');

        -- Validation: Check required fields
        IF @FirstName = '' OR @LastName = '' OR @Email = ''
        BEGIN
            THROW 50001, 'FirstName, LastName, and Email are required.', 1;
        END

        IF @Salary < 0
        BEGIN
            THROW 50002, 'Salary must be a non-negative value.', 1;
        END

        IF @Status NOT IN ('Active', 'OnLeave', 'Terminated')
        BEGIN
            THROW 50003, 'Status must be Active, OnLeave, or Terminated.', 1;
        END

        -- Determine if record exists
        DECLARE @Exists BIT = 0;
        IF @EmployeeId IS NOT NULL AND @EmployeeId > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.EmployeeG WHERE EmployeeId = @EmployeeId)
            BEGIN
                SET @Exists = 1;
            END
        END

        -- Validate uniqueness of Email against other employees
        IF EXISTS (
            SELECT 1 
            FROM dbo.EmployeeG 
            WHERE Email = @Email 
              AND (@Exists = 0 OR EmployeeId <> @EmployeeId)
        )
        BEGIN
            THROW 50004, 'An employee with this Email already exists.', 1;
        END

        -- Validate uniqueness of EpfNo against other employees
        IF @EpfNo IS NOT NULL AND EXISTS (
            SELECT 1 
            FROM dbo.EmployeeG 
            WHERE EpfNo = @EpfNo 
              AND (@Exists = 0 OR EmployeeId <> @EmployeeId)
        )
        BEGIN
            THROW 50005, 'An employee with this EPF number already exists.', 1;
        END

        -- Validate ManagerId if provided
        IF @ManagerId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.EmployeeG WHERE EmployeeId = @ManagerId)
        BEGIN
            THROW 50006, 'The specified ManagerId does not exist.', 1;
        END

        BEGIN TRANSACTION;

        IF @Exists = 1
        BEGIN
            -- UPDATE Existing Employee
            UPDATE dbo.EmployeeG
            SET FirstName        = @FirstName,
                LastName         = @LastName,
                Email            = @Email,
                PhoneNumber      = @PhoneNumber,
                DateOfBirth      = @DateOfBirth,
                EpfNo            = @EpfNo,
                JobTitle         = @JobTitle,
                Department       = @Department,
                HireDate         = @HireDate,
                TerminationDate  = @TerminationDate,
                Salary           = @Salary,
                Status           = @Status,
                ManagerId        = @ManagerId,
                IsDeleted        = @IsDeleted,
                UpdatedAt        = SYSDATETIMEOFFSET()
            WHERE EmployeeId = @EmployeeId;
        END
        ELSE
        BEGIN
            -- INSERT New Employee
            INSERT INTO dbo.EmployeeG (
                FirstName,
                LastName,
                Email,
                PhoneNumber,
                DateOfBirth,
                EpfNo,
                JobTitle,
                Department,
                HireDate,
                TerminationDate,
                Salary,
                Status,
                ManagerId,
                IsDeleted,
                CreatedAt,
                UpdatedAt
            )
            VALUES (
                @FirstName,
                @LastName,
                @Email,
                @PhoneNumber,
                @DateOfBirth,
                @EpfNo,
                @JobTitle,
                @Department,
                @HireDate,
                @TerminationDate,
                @Salary,
                @Status,
                @ManagerId,
                @IsDeleted,
                SYSDATETIMEOFFSET(),
                NULL
            );

            SET @EmployeeId = SCOPE_IDENTITY();
        END

        COMMIT TRANSACTION;

        -- Return the current state of the employee record
        SELECT 
            EmployeeId,
            FirstName,
            LastName,
            Email,
            PhoneNumber,
            DateOfBirth,
            EpfNo,
            JobTitle,
            Department,
            HireDate,
            TerminationDate,
            Salary,
            Status,
            ManagerId,
            IsDeleted,
            CreatedAt,
            UpdatedAt
        FROM dbo.EmployeeG
        WHERE EmployeeId = @EmployeeId;

    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END
GO
