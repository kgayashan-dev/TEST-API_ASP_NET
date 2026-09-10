using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using TestProject.Data;
using TestProject.Models;
using TestProject.Services;

namespace TestProject.Controllers;

[ApiController]
[Route("[controller]")]
[Produces("application/json")]
public class AuthController : ControllerBase
{
    private readonly DBConnect _dbConnect;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        DBConnect dbConnect,
        IPasswordHasher passwordHasher,
        ILogger<AuthController> logger)
    {
        _dbConnect = dbConnect;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    /// <summary>
    /// Authenticates a user by verifying credentials with Argon2id against dbo.getUserLoginDetails.
    /// Automatically manages failed attempt counters and lockout policies.
    /// </summary>
    [HttpPost("Login")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> Login([FromBody] LoginRequestModel model)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var userName = model.UserName.Trim();

            // 1. Fetch user credentials and security state from DB
            var getUserParams = new List<SqlParameter>
            {
                new("@UserName", SqlDbType.NVarChar, 50) { Value = userName }
            };

            var dataTable = await _dbConnect.ExecuteProcedureAsync("dbo.getUserLoginDetails", getUserParams);

            if (dataTable.Rows.Count == 0)
            {
                return Unauthorized(new { message = "Invalid username or password." });
            }

            var userRow = dataTable.Rows[0];

            // 2. Check Lockout states
            var isLockedPermanently = Convert.ToBoolean(userRow["IsLockedPermanently"]);
            if (isLockedPermanently)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    message = "Your account has been permanently locked. Please contact system administrator."
                });
            }

            var isLockedOut = Convert.ToBoolean(userRow["IsLockedOut"]);
            if (isLockedOut)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new
                {
                    message = "Your account is locked due to multiple failed login attempts. Please contact administrator."
                });
            }

            var storedPasswordHash = userRow["PasswordHash"]?.ToString() ?? string.Empty;

            // 3. Verify password using Argon2id
            var isPasswordValid = _passwordHasher.VerifyPassword(storedPasswordHash, model.Password);

            if (!isPasswordValid)
            {
                // Register failed attempt in DB
                var registerFailedParams = new List<SqlParameter>
                {
                    new("@UserName", SqlDbType.NVarChar, 50) { Value = userName },
                    new("@MaxFailedAttempts", SqlDbType.Int) { Value = 5 }
                };

                var failResult = await _dbConnect.ExecuteProcedureAsync("dbo.RegisterFailedLoginAttempt", registerFailedParams);

                var currentFailedAttempts = Convert.ToInt32(userRow["FailedLoginAttemptCount"]) + 1;
                var nowLocked = false;
                if (failResult.Rows.Count > 0)
                {
                    nowLocked = Convert.ToBoolean(failResult.Rows[0]["IsLockedOut"]);
                    currentFailedAttempts = Convert.ToInt32(failResult.Rows[0]["FailedLoginAttemptCount"]);
                }

                if (nowLocked)
                {
                    return StatusCode(StatusCodes.Status403Forbidden, new
                    {
                        message = "Your account has been locked due to 5 consecutive failed login attempts. Please contact administrator."
                    });
                }

                var remainingAttempts = Math.Max(0, 5 - currentFailedAttempts);
                return Unauthorized(new
                {
                    message = "Invalid username or password.",
                    remainingAttempts
                });
            }

            // 4. Password is valid: Reset failed attempts counter
            var resetFailedParams = new List<SqlParameter>
            {
                new("@UserName", SqlDbType.NVarChar, 50) { Value = userName }
            };
            await _dbConnect.ExecuteProcedureAsync("dbo.ResetFailedLoginAttempt", resetFailedParams);

            // 5. Create and Initialize Session State
            var loginId = Convert.ToInt32(userRow["loginID"]);
            var email = userRow["Email"]?.ToString() ?? string.Empty;
            var fullName = userRow["FullName"]?.ToString() ?? string.Empty;
            var userTitle = userRow["UserTitle"] is DBNull ? null : userRow["UserTitle"]?.ToString();
            var sessionToken = Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32));
            var createdAt = DateTime.UtcNow;
            var expiresInMinutes = 30;
            var expiresAt = createdAt.AddMinutes(expiresInMinutes);

            HttpContext.Session.SetInt32("LoginID", loginId);
            HttpContext.Session.SetString("UserName", userName);
            HttpContext.Session.SetString("FullName", fullName);
            HttpContext.Session.SetString("Email", email);
            if (!string.IsNullOrEmpty(userTitle)) HttpContext.Session.SetString("UserTitle", userTitle);
            HttpContext.Session.SetString("SessionToken", sessionToken);
            HttpContext.Session.SetString("LoginTime", createdAt.ToString("o"));

            // 6. Record Audit Trail for Login
            try
            {
                var auditParams = new List<SqlParameter>
                {
                    new("@TableName", SqlDbType.NVarChar, 100) { Value = "Users" },
                    new("@RecordId", SqlDbType.NVarChar, 100) { Value = loginId.ToString() },
                    new("@ActionType", SqlDbType.VarChar, 20) { Value = "LOGIN" },
                    new("@Module", SqlDbType.NVarChar, 100) { Value = "Auth" },
                    new("@Narration", SqlDbType.NVarChar) { Value = $"User login successful. Session established for {userName} (LoginID: {loginId})." },
                    new("@UserId", SqlDbType.NVarChar, 100) { Value = userName },
                    new("@UserRole", SqlDbType.NVarChar, 50) { Value = (object?)userTitle ?? DBNull.Value },
                    new("@IPAddress", SqlDbType.VarChar, 50) { Value = (object?)HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1" },
                    new("@UserAgent", SqlDbType.NVarChar, 255) { Value = (object?)Request.Headers.UserAgent.ToString() ?? DBNull.Value }
                };
                await _dbConnect.ExecuteProcedureAsync("dbo.usp_InsertAuditTrail", auditParams);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to write audit trail for login.");
            }

            // 7. Construct user profile & security details
            var isPasswordExpired = Convert.ToBoolean(userRow["IsPasswordExpired"]);
            var passwordChangeReminder = Convert.ToBoolean(userRow["PasswordChangeReminder"]);
            var isPwdChanged = Convert.ToBoolean(userRow["isPwdChanged"]);
            var remainingDays = Convert.ToInt32(userRow["RemainingDaysForExpire"]);
            var loginMessage = userRow["LoginMessage"]?.ToString();

            return Ok(new
            {
                message = "Login successful.",
                session = new
                {
                    sessionId = HttpContext.Session.Id,
                    sessionToken,
                    createdAt,
                    expiresAt,
                    idleTimeoutMinutes = expiresInMinutes
                },
                user = new
                {
                    loginID = loginId,
                    userName,
                    fullName,
                    userTitle,
                    displayName = userRow["DisplayName"] is DBNull ? null : userRow["DisplayName"]?.ToString(),
                    contactNumber = userRow["ContactNumber"] is DBNull ? null : userRow["ContactNumber"]?.ToString(),
                    email
                },
                securityStatus = new
                {
                    mustChangePassword = !isPwdChanged,
                    isPasswordExpired,
                    passwordChangeReminder,
                    remainingDaysForExpire = remainingDays,
                    loginMessage = string.IsNullOrWhiteSpace(loginMessage) ? null : loginMessage
                }
            });
        }
        catch (SqlException ex)
        {
            _logger.LogError(ex, "SQL error executing login procedure.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled error during authentication.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves the current active user session, if any.
    /// </summary>
    [HttpGet("Session")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public IActionResult GetSession()
    {
        var loginId = HttpContext.Session.GetInt32("LoginID");
        var userName = HttpContext.Session.GetString("UserName");

        if (!loginId.HasValue || string.IsNullOrEmpty(userName))
        {
            return Unauthorized(new { message = "No active session found or session has expired." });
        }

        return Ok(new
        {
            active = true,
            sessionId = HttpContext.Session.Id,
            sessionToken = HttpContext.Session.GetString("SessionToken"),
            loginID = loginId.Value,
            userName,
            fullName = HttpContext.Session.GetString("FullName"),
            email = HttpContext.Session.GetString("Email"),
            userTitle = HttpContext.Session.GetString("UserTitle"),
            loginTime = HttpContext.Session.GetString("LoginTime")
        });
    }

    /// <summary>
    /// Terminates the current active session and logs the logout event.
    /// </summary>
    [HttpPost("Logout")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    public async Task<IActionResult> Logout()
    {
        var loginId = HttpContext.Session.GetInt32("LoginID");
        var userName = HttpContext.Session.GetString("UserName") ?? "Anonymous";
        var userTitle = HttpContext.Session.GetString("UserTitle");

        if (loginId.HasValue)
        {
            try
            {
                var auditParams = new List<SqlParameter>
                {
                    new("@TableName", SqlDbType.NVarChar, 100) { Value = "Users" },
                    new("@RecordId", SqlDbType.NVarChar, 100) { Value = loginId.Value.ToString() },
                    new("@ActionType", SqlDbType.VarChar, 20) { Value = "LOGOUT" },
                    new("@Module", SqlDbType.NVarChar, 100) { Value = "Auth" },
                    new("@Narration", SqlDbType.NVarChar) { Value = $"User logged out. Session terminated for {userName} (LoginID: {loginId.Value})." },
                    new("@UserId", SqlDbType.NVarChar, 100) { Value = userName },
                    new("@UserRole", SqlDbType.NVarChar, 50) { Value = (object?)userTitle ?? DBNull.Value },
                    new("@IPAddress", SqlDbType.VarChar, 50) { Value = (object?)HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1" },
                    new("@UserAgent", SqlDbType.NVarChar, 255) { Value = (object?)Request.Headers.UserAgent.ToString() ?? DBNull.Value }
                };
                await _dbConnect.ExecuteProcedureAsync("dbo.usp_InsertAuditTrail", auditParams);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "Failed to write audit trail for logout.");
            }
        }

        HttpContext.Session.Clear();

        return Ok(new { message = "Logged out successfully." });
    }
}
