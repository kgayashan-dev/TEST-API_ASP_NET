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
public class AdminController : ControllerBase
{
    private readonly DBConnect _dbConnect;
    private readonly IPasswordHasher _passwordHasher;
    private readonly ILogger<AdminController> _logger;

    public AdminController(DBConnect dbConnect, IPasswordHasher passwordHasher, ILogger<AdminController> logger)
    {
        _dbConnect = dbConnect;
        _passwordHasher = passwordHasher;
        _logger = logger;
    }

    /// <summary>
    /// Inserts a new user or updates an existing user using dbo.InsertOrUpdate_User.
    /// Pass LoginID = null or 0 to INSERT; provide an existing LoginID to UPDATE.
    /// </summary>
    [HttpPost("CreateUser")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> UpsertUser([FromBody] UserUpsertModel model)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var action = model.Action.Trim().ToUpperInvariant();
            var isUpdate = action == "U";

            // LoginID is required for UPDATE
            if (isUpdate && (!model.LoginID.HasValue || model.LoginID.Value <= 0))
            {
                return BadRequest(
                    new { message = "LoginID is required when updating an existing user (Action = 'U')." });
            }

            // Password is mandatory for INSERT
            if (!isUpdate && string.IsNullOrWhiteSpace(model.Password))
            {
                return BadRequest(new { message = "Password is required when creating a new user (Action = 'I')." });
            }

            // Hash password unconditionally using Argon2 if provided
            string? passwordHash = null;
            if (!string.IsNullOrWhiteSpace(model.Password))
            {
                passwordHash = _passwordHasher.HashPassword(model.Password);
            }

            var newLoginIdParam = new SqlParameter("@NewLoginID", SqlDbType.Int)
            {
                Direction = ParameterDirection.InputOutput,
                Value = isUpdate ? model.LoginID.GetValueOrDefault() : DBNull.Value
            };

            var procedureParameters = new List<SqlParameter>
            {
                new("@Action", SqlDbType.Char, 1) { Value = action },
                new("@LoginID", SqlDbType.Int) { Value = isUpdate ? model.LoginID.GetValueOrDefault() : DBNull.Value },
                new("@UserName", SqlDbType.NVarChar, 50) { Value = model.UserName.Trim() },
                new("@FullName", SqlDbType.NVarChar, 150) { Value = model.FullName.Trim() },
                new("@UserTitle", SqlDbType.NVarChar, 50) { Value = (object?)model.UserTitle?.Trim() ?? DBNull.Value },
                new("@DisplayName", SqlDbType.NVarChar, 100)
                    { Value = (object?)model.DisplayName?.Trim() ?? (object?)model.FullName.Trim() ?? DBNull.Value },
                new("@ContactNumber", SqlDbType.NVarChar, 25)
                    { Value = (object?)model.ContactNumber?.Trim() ?? DBNull.Value },
                new("@Email", SqlDbType.NVarChar, 100) { Value = model.Email.Trim().ToLowerInvariant() },
                new("@Password", SqlDbType.NVarChar, 255) { Value = (object?)passwordHash ?? DBNull.Value },
                new("@IsLockedOut", SqlDbType.Bit) { Value = model.IsLockedOut ?? false },
                new("@IsLockedPermanently", SqlDbType.Bit) { Value = model.IsLockedPermanently ?? false },
                new("@IsPwdChanged", SqlDbType.Bit) { Value = model.IsPwdChanged ?? false },
                new("@FailedLoginAttemptCount", SqlDbType.Int) { Value = model.FailedLoginAttemptCount ?? 0 },

                // Context & Audit parameters
                new("@UserID", SqlDbType.NVarChar, 100) { Value = (object?)model.UserId ?? DBNull.Value },
                new("@UserRole", SqlDbType.NVarChar, 50) { Value = (object?)model.UserRole ?? DBNull.Value },
                new("@IPAddress", SqlDbType.VarChar, 100)
                {
                    Value = (object?)model.IPAddress ??
                            (object?)HttpContext.Connection.RemoteIpAddress?.ToString() ?? DBNull.Value
                },

                // Output parameter
                newLoginIdParam
            };

            var dataTable = await _dbConnect.ExecuteProcedureAsync("dbo.InsertOrUpdate_User", procedureParameters);

            if (dataTable.Rows.Count > 0)
            {
                var row = dataTable.Rows[0];
                var result = new Dictionary<string, object?>();
                foreach (DataColumn col in dataTable.Columns)
                {
                    result[col.ColumnName] = row.IsNull(col) ? null : row[col];
                }

                return Ok(new
                {
                    message = isUpdate ? "User Updated Successfully" : "User Created Successfully",
                    data = result
                });
            }

            if (newLoginIdParam.Value != DBNull.Value)
            {
                return Ok(new
                {
                    message = isUpdate ? "User Updated Successfully" : "User Created Successfully",
                    loginId = (int)newLoginIdParam.Value
                });
            }

            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = "No data returned from stored procedure." });
        }
        catch (SqlException ex)
        {
            _logger.LogError(ex, "SQL error executing dbo.InsertOrUpdate_User.");

            // Duplicate UserName (60021) or Duplicate Email (60022)
            if (ex.Number is 60021 or 60022)
            {
                return Conflict(new { message = ex.Message, errorCode = ex.Number });
            }

            // Input validation errors (60001 - 60006, 60017, 60018)
            if (ex.Number is >= 60001 and <= 60018)
            {
                return BadRequest(new { message = ex.Message, errorCode = ex.Number });
            }

            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled error executing user upsert.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
    }

    /// <summary>
    /// Retrieves the list of users from dbo.getUserList with optional filters.
    /// </summary>
    /// <param name="loginId">Optional filter by exact LoginID.</param>
    /// <param name="userName">Optional filter by UserName (exact or partial).</param>
    /// <param name="isLockedOut">Optional filter by lockout status.</param>
    /// <param name="isLockedPermanently">Optional filter by permanent lockout status.</param>
    [HttpGet("GetUserList")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> GetUserList(
        [FromQuery] int? loginId = null,
        [FromQuery] string? userName = null,
        [FromQuery] bool? isLockedOut = null,
        [FromQuery] bool? isLockedPermanently = null)
    {
        try
        {
            var procedureParameters = new List<SqlParameter>
            {
                new("@LoginID", SqlDbType.Int) { Value = (object?)loginId ?? DBNull.Value },
                new("@UserName", SqlDbType.NVarChar, 50)
                    { Value = string.IsNullOrWhiteSpace(userName) ? DBNull.Value : userName.Trim() },
                new("@IsLockedOut", SqlDbType.Bit) { Value = (object?)isLockedOut ?? DBNull.Value },
                new("@IsLockedPermanently", SqlDbType.Bit) { Value = (object?)isLockedPermanently ?? DBNull.Value }
            };

            var dataTable = await _dbConnect.ExecuteProcedureAsync("dbo.getUserList", procedureParameters);

            var users = new List<Dictionary<string, object?>>();
            foreach (DataRow row in dataTable.Rows)
            {
                var user = new Dictionary<string, object?>();
                foreach (DataColumn col in dataTable.Columns)
                {
                    user[col.ColumnName] = row.IsNull(col) ? null : row[col];
                }

                users.Add(user);
            }

            return Ok(new
            {
                count = users.Count,
                users = users
            });
        }
        catch (SqlException ex)
        {
            _logger.LogError(ex, "SQL error executing dbo.getUserList.");
            return StatusCode(StatusCodes.Status500InternalServerError,
                new { message = ex.Message, errorCode = ex.Number });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled error executing GetUserList.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
    }
}