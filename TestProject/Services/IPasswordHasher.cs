namespace TestProject.Services;

public interface IPasswordHasher // hidden
{
    /// <summary>
    /// Hashes a plaintext password using Argon2id.
    /// </summary>
    string HashPassword(string password);

    /// <summary>
    /// Verifies a plaintext password against an Argon2 hash string.
    /// </summary>
    bool VerifyPassword(string hash, string password);
}
