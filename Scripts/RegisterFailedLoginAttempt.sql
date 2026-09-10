-- ==========================================================
-- Database: GayashanTest
-- Procedure: dbo.RegisterFailedLoginAttempt
-- Description: Increments failed login count, updates timestamp, and locks
--              user account when maximum threshold is reached.
--              Template based on FINNECT_CENTRAL.[dbo].[RegisterFailedLoginAttempt].
-- ==========================================================

USE GayashanTest;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[RegisterFailedLoginAttempt]
(
    @UserName           NVARCHAR(50),
    @MaxFailedAttempts  INT = 5
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE dbo.Users
    SET
        FailedLoginAttemptCount = ISNULL(FailedLoginAttemptCount, 0) + 1,
        LastFailedLoginDate = SYSUTCDATETIME(),
        IsLockedOut =
            CASE
                WHEN ISNULL(FailedLoginAttemptCount, 0) + 1 >= @MaxFailedAttempts THEN 1
                ELSE IsLockedOut
            END
    WHERE UserName = @UserName;

    -- Return updated status
    SELECT
        UserName,
        FailedLoginAttemptCount,
        IsLockedOut,
        CASE 
            WHEN IsLockedOut = 1 THEN 1
            ELSE 0 
        END AS JustLockedOut
    FROM dbo.Users
    WHERE UserName = @UserName;
END;
GO
