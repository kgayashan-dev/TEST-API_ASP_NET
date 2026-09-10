-- ==========================================================
-- Database: GayashanTest
-- Procedure: dbo.ResetFailedLoginAttempt
-- Description: Resets failed login attempt counter and timestamp upon successful authentication.
--              Template based on FINNECT_CENTRAL.[dbo].[ResetFailedLoginAttempt].
-- ==========================================================

USE GayashanTest;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[ResetFailedLoginAttempt]
(
    @UserName NVARCHAR(50)
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    UPDATE dbo.Users
    SET
        FailedLoginAttemptCount = 0,
        LastFailedLoginDate = NULL
    WHERE UserName = @UserName;
END;
GO
