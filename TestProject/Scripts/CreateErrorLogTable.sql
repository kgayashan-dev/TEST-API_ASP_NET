-- Table to record application and stored procedure errors
IF NOT EXISTS (SELECT 1 FROM sys.tables WHERE name = 'ErrorLog' AND schema_id = SCHEMA_ID('dbo'))
BEGIN
    CREATE TABLE dbo.ErrorLog
    (
        ErrorId         BIGINT IDENTITY(1,1) NOT NULL,
        ErrorNumber     INT                  NULL,
        ErrorSeverity   INT                  NULL,
        ErrorState      INT                  NULL,
        ErrorProcedure  NVARCHAR(128)        NULL,
        ErrorLine       INT                  NULL,
        ErrorMessage    NVARCHAR(MAX)        NOT NULL,
        AdditionalInfo  NVARCHAR(MAX)        NULL,        -- JSON snapshot of input parameters/context
        UserId          NVARCHAR(100)        NULL,
        UserRole        NVARCHAR(50)         NULL,
        IPAddress       VARCHAR(50)          NULL,
        HostName        NVARCHAR(128)        NULL CONSTRAINT DF_ErrorLog_HostName DEFAULT HOST_NAME(),
        AppName         NVARCHAR(128)        NULL CONSTRAINT DF_ErrorLog_AppName DEFAULT APP_NAME(),
        ErrorTimeUtc    DATETIME2(7)         NOT NULL CONSTRAINT DF_ErrorLog_ErrorTimeUtc DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_ErrorLog PRIMARY KEY CLUSTERED (ErrorId ASC)
    );

    CREATE NONCLUSTERED INDEX IX_ErrorLog_ErrorTimeUtc
        ON dbo.ErrorLog (ErrorTimeUtc DESC);

    CREATE NONCLUSTERED INDEX IX_ErrorLog_ErrorProcedure
        ON dbo.ErrorLog (ErrorProcedure, ErrorTimeUtc DESC);
END
GO
