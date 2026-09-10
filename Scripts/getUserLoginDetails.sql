-- ==========================================================
-- Database: GayashanTest
-- Procedure: dbo.getUserLoginDetails
-- Description: Retrieves user credentials, lockout flags, and password expiry
--              details for authentication verification.
--              Template based on FINNECT_CENTRAL.[dbo].[getUserLoginDetails].
-- ==========================================================

USE GayashanTest;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[getUserLoginDetails]
(
    @UserName NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;

    ------------------------------------------------------------
    -- Configurable values
    ------------------------------------------------------------
    DECLARE @PasswordExpiryDays INT = 45;
    DECLARE @ReminderDays       INT = 7;

    ------------------------------------------------------------
    -- Main Query
    ------------------------------------------------------------
    SELECT
        U.loginID,
        U.UserName,
        U.FullName,
        U.UserTitle,
        U.DisplayName,
        U.ContactNumber,
        U.Email,
        U.[Password] AS PasswordHash,
        U.IsLockedOut,
        U.IsLockedPermanently,
        U.PermanentlyLockedDate,
        U.LastPasswordChangedDate,
        U.sysdate,

        ------------------------------------------------------------
        -- Remaining Days
        ------------------------------------------------------------
        CASE
            WHEN U.LastPasswordChangedDate IS NULL THEN 0
            WHEN DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) < 0 THEN 0
            ELSE DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate))
        END AS RemainingDaysForExpire,

        ------------------------------------------------------------
        -- Expired
        ------------------------------------------------------------
        CASE
            WHEN U.LastPasswordChangedDate IS NULL THEN 0
            WHEN DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) <= 0 THEN 1
            ELSE 0
        END AS IsPasswordExpired,

        ------------------------------------------------------------
        -- Reminder
        ------------------------------------------------------------
        CASE
            WHEN U.LastPasswordChangedDate IS NOT NULL
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) <= @ReminderDays
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) > 0
            THEN 1
            ELSE 0
        END AS PasswordChangeReminder,

        ------------------------------------------------------------
        -- Effective isPwdChanged
        ------------------------------------------------------------
        CASE
            WHEN U.LastPasswordChangedDate IS NOT NULL 
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) <= 0 THEN 0
            ELSE U.isPwdChanged
        END AS isPwdChanged,

        U.FailedLoginAttemptCount,
        U.LastFailedLoginDate,

        ------------------------------------------------------------
        -- Login Message (Priority based)
        ------------------------------------------------------------
        CASE
            --------------------------------------------------------
            -- 1. Permanently Locked
            --------------------------------------------------------
            WHEN U.IsLockedPermanently = 1 THEN
                'Your account has been permanently locked. Please contact system administrator.'

            --------------------------------------------------------
            -- 2. Temporarily Locked
            --------------------------------------------------------
            WHEN U.IsLockedOut = 1 THEN
                'Your account is locked due to multiple failed login attempts. Please contact administrator.'

            --------------------------------------------------------
            -- 3. Password Expired
            --------------------------------------------------------
            WHEN U.LastPasswordChangedDate IS NOT NULL 
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) <= 0 THEN
                'Your password has expired. Please change your password to continue.'

            --------------------------------------------------------
            -- 4. Password Reminder
            --------------------------------------------------------
            WHEN U.LastPasswordChangedDate IS NOT NULL 
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) <= @ReminderDays
                 AND DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate)) > 0 THEN
                'Your password will expire in ' +
                CAST(
                    DATEDIFF(DAY, GETDATE(), DATEADD(DAY, @PasswordExpiryDays, U.LastPasswordChangedDate))
                    AS VARCHAR(10)
                ) + ' day(s). Please consider changing it soon.'

            --------------------------------------------------------
            -- 5. First-time / forced password change
            --------------------------------------------------------
            WHEN U.isPwdChanged = 0 THEN
                'You must change your password before continuing.'

            --------------------------------------------------------
            -- 6. Failed Attempts (optional info)
            --------------------------------------------------------
            WHEN U.FailedLoginAttemptCount > 0 THEN
                'Login success with ' + CAST(U.FailedLoginAttemptCount AS VARCHAR(10)) +
                ' failed login attempt(s).'

            --------------------------------------------------------
            -- 7. Default
            --------------------------------------------------------
            ELSE
                ''
        END AS LoginMessage

    FROM dbo.Users U
    WHERE U.UserName = @UserName;
END;
GO
