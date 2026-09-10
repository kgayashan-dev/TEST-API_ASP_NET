using System.ComponentModel.DataAnnotations;

namespace TestProject.Models;

/// <summary>
/// Request model for user authentication.
/// </summary>
public class LoginRequestModel
{
    [Required(ErrorMessage = "UserName is required.")]
    [StringLength(50, ErrorMessage = "UserName cannot exceed 50 characters.")]
    public string UserName { get; set; } = string.Empty;

    [Required(ErrorMessage = "Password is required.")]
    public string Password { get; set; } = string.Empty;
}
