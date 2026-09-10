-- ==========================================================
-- Database: GayashanTest
-- Object: Stored Procedure [dbo].[InsertOrUpdate_User]
-- Description: Inserts or updates a user in [dbo].[Users]
--              following the organization's stored procedure template
--              (based on FINNECT_CENTRAL.[dbo].[InsertOrUpdate_ClientProfile]).
-- ==========================================================

USE GayashanTest;
GO

CREATE OR ALTER PROCEDURE dbo.InsertOrUpdate_User
(
    @Action                  CHAR(1),                    -- 'I' = Insert, 'U' = Update
    @LoginID                 INT            = NULL,      -- Required for Update
    @UserName                NVARCHAR(50),
    @FullName                NVARCHAR(150),
    @UserTitle               NVARCHAR(50)   = NULL,
    @DisplayName             NVARCHAR(100)  = NULL,
    @ContactNumber           NVARCHAR(25)   = NULL,
    @Email                   NVARCHAR(100),
    @Password                NVARCHAR(255)  = NULL,      -- Required for Insert, optional for Update
    @IsLockedOut             BIT            = 0,
    @IsLockedPermanently     BIT            = 0,
    @IsPwdChanged            BIT            = 0,
    @FailedLoginAttemptCount INT            = 0,

    -- Audit & Context Parameters
    @UserID                  NVARCHAR(100)  = NULL,      -- Acting user performing the operation
    @UserRole                NVARCHAR(50)   = NULL,
    @IPAddress               VARCHAR(100)   = NULL,

    -- Output Parameters
    @NewLoginID              INT            = NULL OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @ProcName       SYSNAME = OBJECT_NAME(@@PROCID),
        @StartedTran    BIT = 0,
        @Narration      NVARCHAR(MAX),
        @OldValues      NVARCHAR(MAX) = NULL,
        @NewValues      NVARCHAR(MAX) = NULL,
        @ActionType     VARCHAR(20);

    SET @NewLoginID = NULL;

    BEGIN TRY
        ------------------------------------------------------------
        -- Transaction Setup (with Nested Transaction / Savepoint support)
        ------------------------------------------------------------
        IF @@TRANCOUNT = 0
        BEGIN
            SET @StartedTran = 1;
            BEGIN TRAN;
        END
        ELSE
        BEGIN
            SAVE TRAN User_SP;
        END

        ------------------------------------------------------------
        -- Normalize Inputs
        ------------------------------------------------------------
        SET @Action = UPPER(LTRIM(RTRIM(ISNULL(@Action, ''))));
        SET @UserName = LTRIM(RTRIM(ISNULL(@UserName, '')));
        SET @FullName = LTRIM(RTRIM(ISNULL(@FullName, '')));
        SET @UserTitle = NULLIF(LTRIM(RTRIM(ISNULL(@UserTitle, ''))), '');
        SET @DisplayName = NULLIF(LTRIM(RTRIM(ISNULL(@DisplayName, ''))), '');
        SET @ContactNumber = NULLIF(LTRIM(RTRIM(ISNULL(@ContactNumber, ''))), '');
        SET @Email = LOWER(LTRIM(RTRIM(ISNULL(@Email, ''))));
        SET @Password = NULLIF(LTRIM(RTRIM(ISNULL(@Password, ''))), '');

        -- Default DisplayName to FullName if omitted
        IF @DisplayName IS NULL AND @FullName <> ''
            SET @DisplayName = @FullName;

        ------------------------------------------------------------
        -- General Validations
        ------------------------------------------------------------
        IF @Action NOT IN ('I', 'U')
            THROW 60001, 'Invalid Action. Use ''I'' for Insert or ''U'' for Update.', 1;

        IF @UserName = ''
            THROW 60002, 'UserName is required.', 1;

        IF @FullName = ''
            THROW 60003, 'FullName is required.', 1;

        IF @Email = ''
            THROW 60004, 'Email is required.', 1;

        IF @Email LIKE '% %' OR @Email NOT LIKE '%_@_%._%'
            THROW 60005, 'Invalid Email format.', 1;

        ------------------------------------------------------------
        -- Action: INSERT ('I')
        ------------------------------------------------------------
        IF @Action = 'I'
        BEGIN
            IF @Password IS NULL
                THROW 60006, 'Password is required when inserting a new user.', 1;

            -- Unique validation: UserName
            IF EXISTS (SELECT 1 FROM dbo.Users WHERE UserName = @UserName)
                THROW 60021, 'UserName already exists.', 1;

            -- Unique validation: Email
            IF EXISTS (SELECT 1 FROM dbo.Users WHERE Email = @Email)
                THROW 60022, 'Email already exists.', 1;

            INSERT INTO dbo.Users
            (
                UserName,
                FullName,
                UserTitle,
                DisplayName,
                ContactNumber,
                Email,
                [Password],
                IsLockedOut,
                IsLockedPermanently,
                PermanentlyLockedDate,
                LastPasswordChangedDate,
                SysDate,
                IsPwdChanged,
                FailedLoginAttemptCount,
                LastFailedLoginDate
            )
            VALUES
            (
                @UserName,
                @FullName,
                @UserTitle,
                @DisplayName,
                @ContactNumber,
                @Email,
                @Password,
                ISNULL(@IsLockedOut, 0),
                ISNULL(@IsLockedPermanently, 0),
                CASE WHEN @IsLockedPermanently = 1 THEN SYSUTCDATETIME() ELSE NULL END,
                SYSUTCDATETIME(),
                SYSUTCDATETIME(),
                ISNULL(@IsPwdChanged, 0),
                ISNULL(@FailedLoginAttemptCount, 0),
                NULL
            );

            SET @NewLoginID = SCOPE_IDENTITY();
            SET @ActionType = 'INSERT';
        END
        ------------------------------------------------------------
        -- Action: UPDATE ('U')
        ------------------------------------------------------------
        ELSE
        BEGIN
            IF @LoginID IS NULL OR @LoginID <= 0
                THROW 60017, 'LoginID is required for update.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE LoginID = @LoginID)
                THROW 60018, 'User not found.', 1;

            -- Unique validation: UserName against other users
            IF EXISTS (SELECT 1 FROM dbo.Users WHERE LoginID <> @LoginID AND UserName = @UserName)
                THROW 60021, 'UserName already exists for another user.', 1;

            -- Unique validation: Email against other users
            IF EXISTS (SELECT 1 FROM dbo.Users WHERE LoginID <> @LoginID AND Email = @Email)
                THROW 60022, 'Email already exists for another user.', 1;

            -- Capture state BEFORE update for audit trail
            SELECT @OldValues = (
                SELECT 
                    LoginID, UserName, FullName, UserTitle, DisplayName,
                    ContactNumber, Email, IsLockedOut, IsLockedPermanently,
                    PermanentlyLockedDate, LastPasswordChangedDate,
                    IsPwdChanged, FailedLoginAttemptCount, LastFailedLoginDate
                FROM dbo.Users
                WHERE LoginID = @LoginID
                FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
            );

            UPDATE dbo.Users
            SET UserName                = @UserName,
                FullName                = @FullName,
                UserTitle               = @UserTitle,
                DisplayName             = @DisplayName,
                ContactNumber           = @ContactNumber,
                Email                   = @Email,
                [Password]              = ISNULL(@Password, [Password]),
                IsLockedOut             = ISNULL(@IsLockedOut, IsLockedOut),
                IsLockedPermanently     = ISNULL(@IsLockedPermanently, IsLockedPermanently),
                PermanentlyLockedDate   = CASE 
                                            WHEN @IsLockedPermanently = 1 AND IsLockedPermanently = 0 THEN SYSUTCDATETIME()
                                            WHEN @IsLockedPermanently = 0 THEN NULL
                                            ELSE PermanentlyLockedDate
                                          END,
                LastPasswordChangedDate = CASE WHEN @Password IS NOT NULL THEN SYSUTCDATETIME() ELSE LastPasswordChangedDate END,
                IsPwdChanged            = CASE WHEN @Password IS NOT NULL THEN 1 ELSE ISNULL(@IsPwdChanged, IsPwdChanged) END,
                FailedLoginAttemptCount = CASE WHEN @IsLockedOut = 0 THEN 0 ELSE ISNULL(@FailedLoginAttemptCount, FailedLoginAttemptCount) END
            WHERE LoginID = @LoginID;

            SET @NewLoginID = @LoginID;
            SET @ActionType = 'UPDATE';
        END

        ------------------------------------------------------------
        -- Capture state AFTER insert/update for audit trail
        ------------------------------------------------------------
        SELECT @NewValues = (
            SELECT 
                LoginID, UserName, FullName, UserTitle, DisplayName,
                ContactNumber, Email, IsLockedOut, IsLockedPermanently,
                PermanentlyLockedDate, LastPasswordChangedDate,
                IsPwdChanged, FailedLoginAttemptCount, LastFailedLoginDate
            FROM dbo.Users
            WHERE LoginID = @NewLoginID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

        ------------------------------------------------------------
        -- Audit Logging
        ------------------------------------------------------------
        SET @Narration =
            CASE WHEN @Action = 'I' THEN 'Inserted User Profile. '
                 ELSE 'Updated User Profile. ' END +
            'LoginID=' + CAST(@NewLoginID AS VARCHAR(20)) +
            ', UserName=' + ISNULL(@UserName, '') +
            ', Fullname=' + ISNULL(@FullName, '') +
            ', Email=' + ISNULL(@Email, '') + '.';

        DECLARE @AuditId BIGINT;
        DECLARE @RecordIdStr NVARCHAR(100) = CAST(@NewLoginID AS NVARCHAR(100));

        EXEC dbo.usp_InsertAuditTrail
            @TableName       = N'Users',
            @RecordId        = @RecordIdStr,
            @ActionType      = @ActionType,
            @OldValues       = @OldValues,
            @NewValues       = @NewValues,
            @AffectedColumns = NULL,
            @Module          = N'UserManagement',
            @Narration       = @Narration,
            @UserId          = @UserID,
            @UserRole        = @UserRole,
            @IPAddress       = @IPAddress,
            @UserAgent       = N'StoredProcedure [dbo].[InsertOrUpdate_User]',
            @AuditId         = @AuditId OUTPUT,
            @ReturnRecord    = 0;

        IF @StartedTran = 1
            COMMIT TRAN;

        ------------------------------------------------------------
        -- Return Final Record
        ------------------------------------------------------------
        SELECT
            LoginID,
            UserName,
            FullName,
            UserTitle,
            DisplayName,
            ContactNumber,
            Email,
            IsLockedOut,
            IsLockedPermanently,
            PermanentlyLockedDate,
            LastPasswordChangedDate,
            SysDate,
            IsPwdChanged,
            FailedLoginAttemptCount,
            LastFailedLoginDate
        FROM dbo.Users
        WHERE LoginID = @NewLoginID;

    END TRY
    BEGIN CATCH
        DECLARE
            @ErrorNumber     INT            = ERROR_NUMBER(),
            @ErrorSeverity   INT            = ERROR_SEVERITY(),
            @ErrorState      INT            = ERROR_STATE(),
            @ErrorLine       INT            = ERROR_LINE(),
            @ErrorMessage    NVARCHAR(4000) = ERROR_MESSAGE(),
            @ErrorProcedure  NVARCHAR(256)  = ERROR_PROCEDURE();

        IF XACT_STATE() = -1
        BEGIN
            IF @StartedTran = 1
                ROLLBACK TRAN;
        END
        ELSE IF XACT_STATE() = 1
        BEGIN
            IF @StartedTran = 1
                ROLLBACK TRAN;
            ELSE
                ROLLBACK TRAN User_SP;
        END

        -- Record error into dbo.ErrorLog
        BEGIN TRY
            INSERT INTO dbo.ErrorLog
            (
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
            VALUES
            (
                @ErrorNumber,
                @ErrorSeverity,
                @ErrorState,
                ISNULL(@ErrorProcedure, @ProcName),
                @ErrorLine,
                @ErrorMessage,
                CONCAT('Action=', @Action, '; LoginID=', @LoginID, '; UserName=', @UserName, '; Email=', @Email),
                @UserID,
                @UserRole,
                @IPAddress,
                SYSUTCDATETIME()
            );
        END TRY
        BEGIN CATCH
            -- Suppress secondary logging error so original error is thrown
        END CATCH;

        THROW;
    END CATCH
END
GO
