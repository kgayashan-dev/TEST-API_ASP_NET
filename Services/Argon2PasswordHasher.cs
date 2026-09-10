using Isopoh.Cryptography.Argon2;

namespace TestProject.Services;

/// <summary>
/// Provides secure password hashing and verification using the Argon2id algorithm.
/// Generates standard PHC string format hashes containing parameters, version, salt, and digest.
/// </summary>
public class Argon2PasswordHasher : IPasswordHasher
{
    /// <inheritdoc />
    public string HashPassword(string password)
    {
        if (string.IsNullOrWhiteSpace(password))
            throw new ArgumentException("Password cannot be null or empty.", nameof(password));

        return Argon2.Hash(password);// hashed
    }

    /// <inheritdoc />
    public bool VerifyPassword(string hash, string password)
    {
        if (string.IsNullOrWhiteSpace(hash) || string.IsNullOrWhiteSpace(password))
            return false;

        return Argon2.Verify(hash, password);
    }
}
