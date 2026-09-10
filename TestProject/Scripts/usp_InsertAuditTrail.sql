-- ==========================================================
-- Database: GayashanTest
-- Object: Stored Procedure [dbo].[usp_InsertAuditTrail]
-- Description: Inserts an audit log entry into [dbo].[AuditTrail].
-- ==========================================================

USE GayashanTest;
GO

CREATE OR ALTER PROCEDURE dbo.usp_InsertAuditTrail
    @TableName          NVARCHAR(100),
    @RecordId           NVARCHAR(100),
    @ActionType         VARCHAR(20),
    @OldValues          NVARCHAR(MAX)       = NULL,
    @NewValues          NVARCHAR(MAX)       = NULL,
    @AffectedColumns    NVARCHAR(MAX)       = NULL,
    @Module             NVARCHAR(100)       = NULL,
    @Narration          NVARCHAR(MAX)       = NULL,
    @UserId             NVARCHAR(100)       = NULL,
    @UserRole           NVARCHAR(50)        = NULL,
    @IPAddress          VARCHAR(50)         = NULL,
    @UserAgent          NVARCHAR(255)       = NULL,
    @AuditId            BIGINT              = NULL OUTPUT,
    @ReturnRecord       BIT                 = 1
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Clean and normalize inputs
        SET @TableName  = LTRIM(RTRIM(@TableName));
        SET @RecordId   = LTRIM(RTRIM(@RecordId));
        SET @ActionType = UPPER(LTRIM(RTRIM(@ActionType)));

        -- Basic validation
        IF @TableName = ''
        BEGIN
            THROW 51001, 'TableName cannot be empty.', 1;
        END

        IF @RecordId = ''
        BEGIN
            THROW 51002, 'RecordId cannot be empty.', 1;
        END

        IF @ActionType NOT IN ('INSERT', 'UPDATE', 'DELETE', 'VIEW', 'LOGIN', 'LOGOUT', 'EXECUTE')
        BEGIN
            THROW 51003, 'Invalid ActionType. Allowed values: INSERT, UPDATE, DELETE, VIEW, LOGIN, LOGOUT, EXECUTE.', 1;
        END

        -- Insert audit entry
        INSERT INTO dbo.AuditTrail (
            TableName,
            RecordId,
            ActionType,
            OldValues,
            NewValues,
            AffectedColumns,
            Module,
            Narration,
            UserId,
            UserRole,
            IPAddress,
            UserAgent,
            TimestampUtc
        )
        VALUES (
            @TableName,
            @RecordId,
            @ActionType,
            @OldValues,
            @NewValues,
            @AffectedColumns,
            @Module,
            @Narration,
            @UserId,
            @UserRole,
            @IPAddress,
            @UserAgent,
            SYSUTCDATETIME()
        );

        -- Capture generated identity
        SET @AuditId = SCOPE_IDENTITY();

        -- Return newly created audit record if requested
        IF @ReturnRecord = 1
        BEGIN
            SELECT 
                AuditId,
                TableName,
                RecordId,
                ActionType,
                OldValues,
                NewValues,
                AffectedColumns,
                Module,
                Narration,
                UserId,
                UserRole,
                IPAddress,
                UserAgent,
                TimestampUtc
            FROM dbo.AuditTrail
            WHERE AuditId = @AuditId;
        END

    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END
GO
