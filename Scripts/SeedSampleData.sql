-- ==========================================================
-- Database: GayashanTest
-- Script: SeedSampleData.sql
-- Description: Inserts realistic sample data for dbo.Users
--              and dbo.Employee using the upsert stored procedures
--              so that audit trails are populated correctly.
-- ==========================================================

USE GayashanTest;
GO

SET NOCOUNT ON;
PRINT '==========================================================';
PRINT 'Starting Sample Data Seeding for GayashanTest...';
PRINT '==========================================================';

------------------------------------------------------------
-- 1. SEED SAMPLE USERS (via dbo.InsertOrUpdate_User)
------------------------------------------------------------
PRINT 'Seeding Users...';

DECLARE @UsersTable TABLE
(
    UserName                NVARCHAR(50),
    FullName                NVARCHAR(150),
    UserTitle               NVARCHAR(50),
    DisplayName             NVARCHAR(100),
    ContactNumber           NVARCHAR(25),
    Email                   NVARCHAR(100),
    [Password]              NVARCHAR(255),
    IsLockedOut             BIT,
    IsLockedPermanently     BIT,
    FailedLoginAttemptCount INT
);

INSERT INTO @UsersTable
(
    UserName, FullName, UserTitle, DisplayName, ContactNumber,
    Email, [Password], IsLockedOut, IsLockedPermanently, FailedLoginAttemptCount
)
VALUES
('admin.gayashan', 'Gayashan Perera', 'Head of Engineering', 'Gayashan P.', '+94-77-1000001', 'admin.gayashan@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('sarah.jenkins', 'Sarah Jenkins', 'Senior HR Director', 'Sarah J.', '+94-77-1000002', 'sarah.j@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('michael.chang', 'Michael Chang', 'Lead Financial Controller', 'Michael C.', '+94-77-1000003', 'michael.c@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('anura.kumara', 'Anura Kumara', 'Senior Full Stack Engineer', 'Anura K.', '+94-77-1000004', 'anura.k@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('priya.nair', 'Priya Nair', 'QA Automation Lead', 'Priya N.', '+94-77-1000005', 'priya.n@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('kevin.taylor', 'Kevin Taylor', 'DevOps & Cloud Architect', 'Kevin T.', '+94-77-1000006', 'kevin.t@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 0, 0),
('locked.demo', 'Account Locked User', 'Junior Operator', 'Locked User', '+94-77-1000007', 'locked.demo@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 1, 0, 5),
('retired.staff', 'Retired Staff Member', 'Former Manager', 'Retired User', '+94-77-1000008', 'retired.staff@finnect.com', '$argon2id$v=19$m=65536,t=3,p=1$QGIpSKY6ymmqLH6pN6+rxg$IOF262nO7qx1CB9GQjc1Rn+/EjLCjTh0Uy4t1Wzv/Z0', 0, 1, 0);

DECLARE 
    @uName NVARCHAR(50), @uFull NVARCHAR(150), @uTitle NVARCHAR(50), 
    @uDisp NVARCHAR(100), @uContact NVARCHAR(25), @uEmail NVARCHAR(100), 
    @uPwd NVARCHAR(255), @uLock BIT, @uPermLock BIT, @uFailed INT,
    @outLoginID INT;

DECLARE user_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT 
    UserName, FullName, UserTitle, DisplayName, ContactNumber,
    Email, [Password], IsLockedOut, IsLockedPermanently, FailedLoginAttemptCount
FROM @UsersTable;

OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO 
    @uName, @uFull, @uTitle, @uDisp, @uContact, 
    @uEmail, @uPwd, @uLock, @uPermLock, @uFailed;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE UserName = @uName OR Email = @uEmail)
    BEGIN
        EXEC dbo.InsertOrUpdate_User
            @Action                  = 'I',
            @UserName                = @uName,
            @FullName                = @uFull,
            @UserTitle               = @uTitle,
            @DisplayName             = @uDisp,
            @ContactNumber           = @uContact,
            @Email                   = @uEmail,
            @Password                = @uPwd,
            @IsLockedOut             = @uLock,
            @IsLockedPermanently     = @uPermLock,
            @FailedLoginAttemptCount = @uFailed,
            @UserID                  = 'data-seeder',
            @UserRole                = 'Admin',
            @IPAddress               = '127.0.0.1',
            @NewLoginID              = @outLoginID OUTPUT;

        PRINT '  + User seeded: ' + @uName + ' (LoginID: ' + CAST(@outLoginID AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        PRINT '  . User already exists: ' + @uName;
    END

    FETCH NEXT FROM user_cursor INTO 
        @uName, @uFull, @uTitle, @uDisp, @uContact, 
        @uEmail, @uPwd, @uLock, @uPermLock, @uFailed;
END;

CLOSE user_cursor;
DEALLOCATE user_cursor;


------------------------------------------------------------
-- 2. SEED SAMPLE EMPLOYEES (via dbo.usp_UpsertEmployee)
------------------------------------------------------------
PRINT 'Seeding Employees...';

DECLARE @EmployeesTable TABLE
(
    FirstName        NVARCHAR(50),
    LastName         NVARCHAR(50),
    Email            NVARCHAR(100),
    PhoneNumber      NVARCHAR(20),
    DateOfBirth      DATE,
    Gender           VARCHAR(10),
    EpfNo            NVARCHAR(30),
    JobTitle         NVARCHAR(100),
    Department       NVARCHAR(50),
    HireDate         DATE,
    TerminationDate  DATE,
    EmploymentStatus VARCHAR(20),
    Salary           DECIMAL(18,2),
    IsActive         BIT
);

INSERT INTO @EmployeesTable
(
    FirstName, LastName, Email, PhoneNumber, DateOfBirth, Gender, EpfNo,
    JobTitle, Department, HireDate, TerminationDate, EmploymentStatus, Salary, IsActive
)
VALUES
('Nuwan', 'Pradeep', 'nuwan.pradeep@finnect.com', '+94-77-2000001', '1992-04-15', 'Male', 'EPF-1001', 'Senior Backend Engineer', 'Technology', '2021-03-01', NULL, 'Full-Time', 165000.00, 1),
('Dilani', 'Fernando', 'dilani.fernando@finnect.com', '+94-77-2000002', '1994-08-22', 'Female', 'EPF-1002', 'HR Business Partner', 'Human Resources', '2022-01-15', NULL, 'Full-Time', 130000.00, 1),
('Kusal', 'Mendis', 'kusal.mendis@finnect.com', '+94-77-2000003', '1995-02-10', 'Male', 'EPF-1003', 'Senior Financial Analyst', 'Finance', '2020-07-01', NULL, 'Full-Time', 145000.00, 1),
('Chamari', 'Athapaththu', 'chamari.a@finnect.com', '+94-77-2000004', '1990-11-05', 'Female', 'EPF-1004', 'Head of Marketing', 'Marketing', '2019-09-01', NULL, 'Full-Time', 230000.00, 1),
('Angelo', 'Mathews', 'angelo.mathews@finnect.com', '+94-77-2000005', '1987-06-02', 'Male', 'EPF-1005', 'Operations Director', 'Operations', '2018-04-10', NULL, 'Full-Time', 260000.00, 1),
('Harshana', 'Dias', 'harshana.dias@finnect.com', '+94-77-2000006', '1993-01-19', 'Male', 'EPF-1006', 'Cloud Security Specialist', 'Technology', '2022-05-20', NULL, 'Full-Time', 190000.00, 1),
('Sanduni', 'Wickramasinghe', 'sanduni.w@finnect.com', '+94-77-2000007', '1996-09-14', 'Female', 'EPF-1007', 'Lead UI/UX Designer', 'Technology', '2023-02-01', NULL, 'Full-Time', 140000.00, 1),
('Dinesh', 'Chandimal', 'dinesh.c@finnect.com', '+94-77-2000008', '1989-11-18', 'Male', 'EPF-1008', 'Corporate Legal Counsel', 'Legal', '2019-10-15', NULL, 'Full-Time', 250000.00, 1),
('Tharushi', 'Karunaratne', 'tharushi.k@finnect.com', '+94-77-2000009', '1998-03-25', 'Female', 'EPF-1009', 'Talent Acquisition Executive', 'Human Resources', '2023-08-01', NULL, 'Full-Time', 95000.00, 1),
('Lasith', 'Malinga', 'lasith.malinga@finnect.com', '+94-77-2000010', '1983-08-28', 'Male', 'EPF-1010', 'DevOps Infrastructure Consultant', 'Technology', '2024-01-10', NULL, 'Contract', 210000.00, 1);

DECLARE
    @eFirst NVARCHAR(50), @eLast NVARCHAR(50), @eEmail NVARCHAR(100),
    @ePhone NVARCHAR(20), @eDOB DATE, @eGender VARCHAR(10), @eEpf NVARCHAR(30),
    @eJob NVARCHAR(100), @eDept NVARCHAR(50), @eHire DATE, @eTerm DATE,
    @eStatus VARCHAR(20), @eSalary DECIMAL(18,2), @eActive BIT,
    @outEmpId INT;

DECLARE emp_cursor CURSOR LOCAL FAST_FORWARD FOR
SELECT
    FirstName, LastName, Email, PhoneNumber, DateOfBirth, Gender, EpfNo,
    JobTitle, Department, HireDate, TerminationDate, EmploymentStatus, Salary, IsActive
FROM @EmployeesTable;

OPEN emp_cursor;
FETCH NEXT FROM emp_cursor INTO
    @eFirst, @eLast, @eEmail, @ePhone, @eDOB, @eGender, @eEpf,
    @eJob, @eDept, @eHire, @eTerm, @eStatus, @eSalary, @eActive;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT 1 FROM dbo.Employee WHERE Email = @eEmail OR EpfNo = @eEpf)
    BEGIN
        SET @outEmpId = NULL;
        EXEC dbo.usp_UpsertEmployee
            @EmployeeId       = @outEmpId OUTPUT,
            @FirstName        = @eFirst,
            @LastName         = @eLast,
            @Email            = @eEmail,
            @PhoneNumber      = @ePhone,
            @DateOfBirth      = @eDOB,
            @Gender           = @eGender,
            @EpfNo            = @eEpf,
            @JobTitle         = @eJob,
            @Department       = @eDept,
            @HireDate         = @eHire,
            @TerminationDate  = @eTerm,
            @EmploymentStatus = @eStatus,
            @Salary           = @eSalary,
            @IsActive         = @eActive,
            @UserId           = 'data-seeder',
            @UserRole         = 'Admin',
            @IPAddress        = '127.0.0.1';

        PRINT '  + Employee seeded: ' + @eFirst + ' ' + @eLast + ' (EmployeeId: ' + CAST(@outEmpId AS VARCHAR(10)) + ')';
    END
    ELSE
    BEGIN
        PRINT '  . Employee already exists: ' + @eEmail;
    END

    FETCH NEXT FROM emp_cursor INTO
        @eFirst, @eLast, @eEmail, @ePhone, @eDOB, @eGender, @eEpf,
        @eJob, @eDept, @eHire, @eTerm, @eStatus, @eSalary, @eActive;
END;

CLOSE emp_cursor;
DEALLOCATE emp_cursor;

PRINT '==========================================================';
PRINT 'Sample Data Seeding Completed Successfully!';
PRINT '==========================================================';
GO
