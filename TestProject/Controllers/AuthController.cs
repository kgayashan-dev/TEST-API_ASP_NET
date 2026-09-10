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

            // 5. Construct user profile & security details
            var isPasswordExpired = Convert.ToBoolean(userRow["IsPasswordExpired"]);
            var passwordChangeReminder = Convert.ToBoolean(userRow["PasswordChangeReminder"]);
            var isPwdChanged = Convert.ToBoolean(userRow["isPwdChanged"]);
            var remainingDays = Convert.ToInt32(userRow["RemainingDaysForExpire"]);
            var loginMessage = userRow["LoginMessage"]?.ToString();

            return Ok(new
            {
                message = "Login successful.",
                user = new
                {
                    loginID = Convert.ToInt32(userRow["loginID"]),
                    userName = userRow["UserName"]?.ToString(),
                    fullName = userRow["FullName"]?.ToString(),
                    userTitle = userRow["UserTitle"] is DBNull ? null : userRow["UserTitle"]?.ToString(),
                    displayName = userRow["DisplayName"] is DBNull ? null : userRow["DisplayName"]?.ToString(),
                    contactNumber = userRow["ContactNumber"] is DBNull ? null : userRow["ContactNumber"]?.ToString(),
                    email = userRow["Email"]?.ToString()
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
}
