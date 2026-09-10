using System.ComponentModel.DataAnnotations;

namespace TestProject.Models;

/// <summary>
/// Request model for inserting or updating a user via dbo.InsertOrUpdate_User.
/// Pass LoginID = null or 0 to insert; pass existing LoginID to update.
/// </summary>
public class UserUpsertModel
{
    /// <summary>
    /// User identifier. Pass null or 0 to INSERT; provide existing ID to UPDATE.
    /// </summary>
    public int? LoginID { get; set; }

    /// <summary>
    /// Operation action: 'I' for Insert, 'U' for Update.
    /// </summary>
    [Required(ErrorMessage = "Action is required ('I' for Insert, 'U' for Update).")]
    [RegularExpression("^[IUiU]$", ErrorMessage = "Action must be 'I' (Insert) or 'U' (Update).")]
    public string Action { get; set; } = string.Empty;
    
    [Required(ErrorMessage = "UserName is required.")]
    [StringLength(50, ErrorMessage = "UserName cannot exceed 50 characters.")]
    public string UserName { get; set; } = string.Empty;

    [Required(ErrorMessage = "FullName is required.")]
    [StringLength(150, ErrorMessage = "FullName cannot exceed 150 characters.")]
    public string FullName { get; set; } = string.Empty;

    [StringLength(50, ErrorMessage = "UserTitle cannot exceed 50 characters.")]
    public string? UserTitle { get; set; }

    [StringLength(100, ErrorMessage = "DisplayName cannot exceed 100 characters.")]
    public string? DisplayName { get; set; }

    [StringLength(25, ErrorMessage = "ContactNumber cannot exceed 25 characters.")]
    public string? ContactNumber { get; set; }

    [Required(ErrorMessage = "Email is required.")]
    [EmailAddress(ErrorMessage = "Invalid email address format.")]
    [StringLength(100, ErrorMessage = "Email cannot exceed 100 characters.")]
    public string Email { get; set; } = string.Empty;

    /// <summary>
    /// Password or password hash. Required when creating a new user; optional when updating.
    /// </summary>
    [StringLength(255, ErrorMessage = "Password cannot exceed 255 characters.")]
    public string? Password { get; set; }

    public bool? IsLockedOut { get; set; } = false;

    public bool? IsLockedPermanently { get; set; } = false;

    public bool? IsPwdChanged { get; set; } = false;

    public int? FailedLoginAttemptCount { get; set; } = 0;

    // Optional context / audit fields
    public string? UserId { get; set; }
    public string? UserRole { get; set; }
    public string? IPAddress { get; set; }
}
