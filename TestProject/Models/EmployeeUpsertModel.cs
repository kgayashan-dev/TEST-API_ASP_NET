using System.ComponentModel.DataAnnotations;

namespace TestProject.Models;

/// <summary>
/// Model for creating or updating an employee via dbo.usp_UpsertEmployee.
/// Pass EmployeeId = null or 0 to insert; pass existing EmployeeId to update.
/// </summary>
public class EmployeeUpsertModel
{
    /// <summary>
    /// Employee identifier. Pass null or 0 to INSERT a new record; pass existing ID to UPDATE.
    /// </summary>
    public int? EmployeeId { get; set; }

    [Required(ErrorMessage = "FirstName is required.")]
    [StringLength(50, ErrorMessage = "FirstName cannot exceed 50 characters.")]
    public string FirstName { get; set; } = string.Empty;

    [Required(ErrorMessage = "LastName is required.")]
    [StringLength(50, ErrorMessage = "LastName cannot exceed 50 characters.")]
    public string LastName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress(ErrorMessage = "Invalid email format.")]
    [StringLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
    public string Email { get; set; } = string.Empty;

    [StringLength(20, ErrorMessage = "PhoneNumber cannot exceed 20 characters.")]
    public string? PhoneNumber { get; set; }

    public DateOnly? DateOfBirth { get; set; }

    [StringLength(10, ErrorMessage = "Gender cannot exceed 10 characters.")]
    public string? Gender { get; set; }

    [StringLength(30, ErrorMessage = "EpfNo cannot exceed 30 characters.")]
    public string? EpfNo { get; set; }

    [Required(ErrorMessage = "JobTitle is required.")]
    [StringLength(100, ErrorMessage = "JobTitle cannot exceed 100 characters.")]
    public string JobTitle { get; set; } = string.Empty;

    [Required(ErrorMessage = "Department is required.")]
    [StringLength(50, ErrorMessage = "Department cannot exceed 50 characters.")]
    public string Department { get; set; } = string.Empty;

    [Required(ErrorMessage = "HireDate is required.")]
    public DateOnly HireDate { get; set; }

    public DateOnly? TerminationDate { get; set; }

    [StringLength(20, ErrorMessage = "EmploymentStatus cannot exceed 20 characters.")]
    public string EmploymentStatus { get; set; } = "Full-Time";

    [Range(0, double.MaxValue, ErrorMessage = "Salary must be a non-negative value.")]
    public decimal Salary { get; set; }

    public bool IsActive { get; set; } = true;

    // Optional audit context fields
    public string? UserId { get; set; }
    public string? UserRole { get; set; }
    public string? IPAddress { get; set; }
}

/// <summary>
/// Alias for EmployeeUpsertModel.
/// </summary>
public class EmployeeRequest : EmployeeUpsertModel { }

