-- ==========================================================
-- Database: GayashanTest
-- Object: Stored Procedure [dbo].[usp_UpsertEmployee]
-- Description: Inserts or updates an employee in [dbo].[Employee],
--              calls [dbo].[usp_InsertAuditTrail], and logs errors
--              into [dbo].[ErrorLog].
-- ==========================================================

USE GayashanTest;
GO

CREATE OR ALTER PROCEDURE dbo.usp_UpsertEmployee
    @EmployeeId         INT = NULL OUTPUT,       -- Pass NULL or 0 to INSERT; pass existing ID to UPDATE
    @FirstName          NVARCHAR(50),
    @LastName           NVARCHAR(50),
    @Email              NVARCHAR(100),
    @PhoneNumber        NVARCHAR(20)   = NULL,
    @DateOfBirth        DATE           = NULL,
    @Gender             VARCHAR(10)    = NULL,
    @EpfNo              NVARCHAR(30)   = NULL,
    @JobTitle           NVARCHAR(100),
    @Department         NVARCHAR(50),
    @HireDate           DATE,
    @TerminationDate    DATE           = NULL,
    @EmploymentStatus   VARCHAR(20)    = 'Full-Time',
    @Salary             DECIMAL(18, 2),
    @IsActive           BIT            = 1,
    -- Optional Audit Context Parameters
    @UserId             NVARCHAR(100)  = NULL,
    @UserRole           NVARCHAR(50)   = NULL,
    @IPAddress          VARCHAR(50)    = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        -- 1. Clean & normalize strings
        SET @FirstName = LTRIM(RTRIM(@FirstName));
        SET @LastName  = LTRIM(RTRIM(@LastName));
        SET @Email     = LOWER(LTRIM(RTRIM(@Email)));
        SET @EpfNo     = NULLIF(LTRIM(RTRIM(@EpfNo)), '');

        -- 2. Required field validation
        IF @FirstName = '' OR @LastName = '' OR @Email = ''
        BEGIN
            THROW 50001, 'FirstName, LastName, and Email cannot be empty.', 1;
        END

        IF @Salary < 0
        BEGIN
            THROW 50002, 'Salary must be a non-negative value.', 1;
        END

        -- 3. Determine if record exists
        DECLARE @Exists BIT = 0;
        IF @EmployeeId IS NOT NULL AND @EmployeeId > 0
        BEGIN
            IF EXISTS (SELECT 1 FROM dbo.Employee WHERE EmployeeId = @EmployeeId)
            BEGIN
                SET @Exists = 1;
            END
        END

        -- 4. Check unique Email conflict against other employees
        IF EXISTS (
            SELECT 1
            FROM dbo.Employee
            WHERE Email = @Email
              AND (@Exists = 0 OR EmployeeId <> @EmployeeId)
        )
        BEGIN
            THROW 50003, 'An employee with this Email already exists.', 1;
        END

        -- 5. Check unique EpfNo conflict against other employees
        IF @EpfNo IS NOT NULL AND EXISTS (
            SELECT 1
            FROM dbo.Employee
            WHERE EpfNo = @EpfNo
              AND (@Exists = 0 OR EmployeeId <> @EmployeeId)
        )
        BEGIN
            THROW 50004, 'An employee with this EPF number already exists.', 1;
        END

        -- Variables for audit trail snapshots
        DECLARE @OldValues NVARCHAR(MAX) = NULL;
        DECLARE @NewValues NVARCHAR(MAX) = NULL;
        DECLARE @ActionType VARCHAR(20) = CASE WHEN @Exists = 1 THEN 'UPDATE' ELSE 'INSERT' END;
        DECLARE @Narration NVARCHAR(MAX);

        BEGIN TRANSACTION;

        IF @Exists = 1
        BEGIN
            -- Capture state BEFORE update for audit trail
            SELECT @OldValues = (
                SELECT 
                    EmployeeId, FirstName, LastName, Email, PhoneNumber,
                    DateOfBirth, Gender, EpfNo, JobTitle, Department,
                    HireDate, TerminationDate, EmploymentStatus, Salary, IsActive
                FROM dbo.Employee
                WHERE EmployeeId = @EmployeeId
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            -- UPDATE Existing Employee
            UPDATE dbo.Employee
            SET FirstName        = @FirstName,
                LastName         = @LastName,
                Email            = @Email,
                PhoneNumber      = @PhoneNumber,
                DateOfBirth      = @DateOfBirth,
                Gender           = @Gender,
                EpfNo            = @EpfNo,
                JobTitle         = @JobTitle,
                Department       = @Department,
                HireDate         = @HireDate,
                TerminationDate  = @TerminationDate,
                EmploymentStatus = @EmploymentStatus,
                Salary           = @Salary,
                IsActive         = @IsActive,
                UpdatedAtUtc     = SYSUTCDATETIME()
            WHERE EmployeeId = @EmployeeId;

            SET @Narration = 'Updated employee details for EmployeeId ' + CAST(@EmployeeId AS NVARCHAR(20));
        END
        ELSE
        BEGIN
            -- INSERT New Employee
            INSERT INTO dbo.Employee (
                FirstName,
                LastName,
                Email,
                PhoneNumber,
                DateOfBirth,
                Gender,
                EpfNo,
                JobTitle,
                Department,
                HireDate,
                TerminationDate,
                EmploymentStatus,
                Salary,
                IsActive,
                CreatedAtUtc,
                UpdatedAtUtc
            )
            VALUES (
                @FirstName,
                @LastName,
                @Email,
                @PhoneNumber,
                @DateOfBirth,
                @Gender,
                @EpfNo,
                @JobTitle,
                @Department,
                @HireDate,
                @TerminationDate,
                @EmploymentStatus,
                @Salary,
                @IsActive,
                SYSUTCDATETIME(),
                NULL
            );

            SET @EmployeeId = SCOPE_IDENTITY();
            SET @Narration = 'Created new employee record for ' + @FirstName + ' ' + @LastName;
        END

        -- Capture state AFTER insert/update for audit trail
        SELECT @NewValues = (
            SELECT 
                EmployeeId, FirstName, LastName, Email, PhoneNumber,
                DateOfBirth, Gender, EpfNo, JobTitle, Department,
                HireDate, TerminationDate, EmploymentStatus, Salary, IsActive
            FROM dbo.Employee
            WHERE EmployeeId = @EmployeeId
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        -- Call usp_InsertAuditTrail to populate audit log
        DECLARE @AuditId BIGINT;
        DECLARE @RecordIdStr NVARCHAR(100) = CAST(@EmployeeId AS NVARCHAR(100));

        EXEC dbo.usp_InsertAuditTrail
            @TableName       = N'Employee',
            @RecordId        = @RecordIdStr,
            @ActionType      = @ActionType,
            @OldValues       = @OldValues,
            @NewValues       = @NewValues,
            @AffectedColumns = NULL,
            @Module          = N'EmployeeManagement',
            @Narration       = @Narration,
            @UserId          = @UserId,
            @UserRole        = @UserRole,
            @IPAddress       = @IPAddress,
            @UserAgent       = N'StoredProcedure [dbo].[usp_UpsertEmployee]',
            @AuditId         = @AuditId OUTPUT,
            @ReturnRecord    = 0;

        COMMIT TRANSACTION;

        -- Return the current state of the employee record
        SELECT
            EmployeeId,
            FirstName,
            LastName,
            Email,
            PhoneNumber,
            DateOfBirth,
            Gender,
            EpfNo,
            JobTitle,
            Department,
            HireDate,
            TerminationDate,
            EmploymentStatus,
            Salary,
            IsActive,
            CreatedAtUtc,
            UpdatedAtUtc
        FROM dbo.Employee
        WHERE EmployeeId = @EmployeeId;

    END TRY
    BEGIN CATCH
        -- 1. Roll back transaction if still active
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        -- 2. Capture error information
        DECLARE @ErrNumber    INT            = ERROR_NUMBER();
        DECLARE @ErrSeverity  INT            = ERROR_SEVERITY();
        DECLARE @ErrState     INT            = ERROR_STATE();
        DECLARE @ErrProcedure NVARCHAR(128)  = ERROR_PROCEDURE();
        DECLARE @ErrLine      INT            = ERROR_LINE();
        DECLARE @ErrMessage   NVARCHAR(MAX)  = ERROR_MESSAGE();

        -- 3. Capture parameter context as JSON
        DECLARE @AdditionalInfo NVARCHAR(MAX) = (
            SELECT 
                @EmployeeId       AS EmployeeId,
                @FirstName        AS FirstName,
                @LastName         AS LastName,
                @Email            AS Email,
                @PhoneNumber      AS PhoneNumber,
                @DateOfBirth      AS DateOfBirth,
                @Gender           AS Gender,
                @EpfNo            AS EpfNo,
                @JobTitle         AS JobTitle,
                @Department       AS Department,
                @HireDate         AS HireDate,
                @TerminationDate  AS TerminationDate,
                @EmploymentStatus AS EmploymentStatus,
                @Salary           AS Salary,
                @IsActive         AS IsActive
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        -- 4. Record error in dbo.ErrorLog
        BEGIN TRY
            INSERT INTO dbo.ErrorLog (
                ErrorNumber,
                ErrorSeverity,
                ErrorState,
                ErrorProcedure,
                ErrorLine,
                ErrorMessage,
                AdditionalInfo,
                UserId,
                UserRole,
                IPAddress,
                ErrorTimeUtc
            )
            VALUES (
                @ErrNumber,
                @ErrSeverity,
                @ErrState,
                ISNULL(@ErrProcedure, 'dbo.usp_UpsertEmployee'),
                @ErrLine,
                @ErrMessage,
                @AdditionalInfo,
                @UserId,
                @UserRole,
                @IPAddress,
                SYSUTCDATETIME()
            );
        END TRY
        BEGIN CATCH
            -- Suppress logging failure so original error is always re-thrown
        END CATCH;

        -- 5. Re-throw original error to calling application
        THROW;
    END CATCH
END
GO
