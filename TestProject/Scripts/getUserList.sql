-- ==========================================================
-- Database: GayashanTest
-- Procedure: dbo.getUserList
-- Description: Retrieves users with optional filtering.
--              Template aligned with FINNECT_CENTRAL.[dbo].[getUserList]
-- ==========================================================

USE GayashanTest;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [dbo].[getUserList]
(
    @LoginID             INT          = NULL,
    @UserName            NVARCHAR(50) = NULL,
    @IsLockedOut         BIT          = NULL,
    @IsLockedPermanently BIT          = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        U.LoginID,
        U.UserName,
        U.FullName,
        U.UserTitle,
        U.DisplayName,
        U.ContactNumber,
        U.Email,
        U.IsLockedOut,
        U.IsLockedPermanently,
        U.PermanentlyLockedDate,
        U.LastPasswordChangedDate,
        U.SysDate,
        U.IsPwdChanged,
        U.FailedLoginAttemptCount,
        U.LastFailedLoginDate
    FROM dbo.Users U
    WHERE
        (@LoginID IS NULL OR U.LoginID = @LoginID)
        AND (@UserName IS NULL OR U.UserName LIKE '%' + @UserName + '%')
        AND (@IsLockedOut IS NULL OR U.IsLockedOut = @IsLockedOut)
        AND (@IsLockedPermanently IS NULL OR U.IsLockedPermanently = @IsLockedPermanently)
    ORDER BY U.LoginID;
END;
GO
