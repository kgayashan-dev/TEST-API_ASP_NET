using System.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using TestProject.Data;
using TestProject.Models;

namespace TestProject.Controllers;

[ApiController]
[Route("[controller]")]
[Produces("application/json")]
public class EmployeeController : ControllerBase
{
    private readonly DBConnect _dbConnect;
    private readonly ILogger<EmployeeController> _logger;

    public EmployeeController(DBConnect dbConnect, ILogger<EmployeeController> logger)
    {
        _dbConnect = dbConnect;
        _logger = logger;
    }

    /// <summary>
    /// Executes the dbo.usp_UpsertEmployee stored procedure to insert or update an employee.
    /// Pass EmployeeId = null or 0 to INSERT a new record, or provide an existing EmployeeId to UPDATE.
    /// </summary>
    [HttpPost("CreateEmployee")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status500InternalServerError)]
    public async Task<IActionResult> UpsertEmployee([FromBody] EmployeeUpsertModel model)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var isUpdate = model.EmployeeId.HasValue && model.EmployeeId.Value > 0;

            // Output/InputOutput parameter for procedure
            var employeeIdParam = new SqlParameter("@EmployeeId", SqlDbType.Int)
            {
                Direction = ParameterDirection.InputOutput,
                Value = isUpdate ? model.EmployeeId.GetValueOrDefault() : DBNull.Value
            };

            // Build procedure parameters directly from the typed model
            var procedureParameters = new List<SqlParameter>
            {
                employeeIdParam,
                new("@FirstName", SqlDbType.NVarChar, 50) { Value = model.FirstName.Trim() },
                new("@LastName", SqlDbType.NVarChar, 50) { Value = model.LastName.Trim() },
                new("@Email", SqlDbType.NVarChar, 100) { Value = model.Email.Trim().ToLowerInvariant() },
                new("@PhoneNumber", SqlDbType.NVarChar, 20) { Value = (object?)model.PhoneNumber ?? DBNull.Value },
                new("@DateOfBirth", SqlDbType.Date) { Value = model.DateOfBirth.HasValue ? model.DateOfBirth.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value },
                new("@Gender", SqlDbType.VarChar, 10) { Value = (object?)model.Gender ?? DBNull.Value },
                new("@EpfNo", SqlDbType.NVarChar, 30) { Value = (object?)model.EpfNo ?? DBNull.Value },
                new("@JobTitle", SqlDbType.NVarChar, 100) { Value = model.JobTitle.Trim() },
                new("@Department", SqlDbType.NVarChar, 50) { Value = model.Department.Trim() },
                new("@HireDate", SqlDbType.Date) { Value = model.HireDate.ToDateTime(TimeOnly.MinValue) },
                new("@TerminationDate", SqlDbType.Date) { Value = model.TerminationDate.HasValue ? model.TerminationDate.Value.ToDateTime(TimeOnly.MinValue) : DBNull.Value },
                new("@EmploymentStatus", SqlDbType.VarChar, 20) { Value = string.IsNullOrWhiteSpace(model.EmploymentStatus) ? "Full-Time" : model.EmploymentStatus },
                new("@Salary", SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = model.Salary },
                new("@IsActive", SqlDbType.Bit) { Value = model.IsActive },
                // Optional audit parameters
                new("@UserId", SqlDbType.NVarChar, 100) { Value = (object?)model.UserId ?? DBNull.Value },
                new("@UserRole", SqlDbType.NVarChar, 50) { Value = (object?)model.UserRole ?? DBNull.Value },
                new("@IPAddress", SqlDbType.VarChar, 50) { Value = (object?)model.IPAddress ?? (object?)HttpContext.Connection.RemoteIpAddress?.ToString() ?? DBNull.Value }
            };

            // Execute stored procedure using DBConnect with procedure name and procedure parameters
            var dataTable = await _dbConnect.ExecuteProcedureAsync("dbo.usp_UpsertEmployee", procedureParameters);

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
                    message = isUpdate ? "Updated Successfully" : "Saved Successfully",
                    data = result
                });
            }

            if (employeeIdParam.Value != DBNull.Value)
            {
                return Ok(new
                {
                    message = isUpdate ? "Updated Successfully" : "Saved Successfully",
                    employeeId = (int)employeeIdParam.Value
                });
            }

            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "No data returned from stored procedure." });
        }
        catch (SqlException ex)
        {
            _logger.LogError(ex, "SQL error executing usp_UpsertEmployee.");

            if (ex.Number is 50003 or 50004)
            {
                return Conflict(new { message = ex.Message, errorCode = ex.Number });
            }

            if (ex.Number is 50001 or 50002)
            {
                return BadRequest(new { message = ex.Message, errorCode = ex.Number });
            }

            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Unhandled error executing usp_UpsertEmployee.");
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = ex.Message });
        }
    }
}

