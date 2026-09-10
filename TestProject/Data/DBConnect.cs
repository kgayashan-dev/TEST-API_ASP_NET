using System.Data;
using Microsoft.Data.SqlClient;

namespace TestProject.Data;

public class DBConnect
{
    private readonly string _connectionString;

    public DBConnect(IConfiguration configuration)
    {
        _connectionString = configuration.GetConnectionString("DefaultConnection")
            ?? throw new InvalidOperationException("Connection string 'DefaultConnection' not found in configuration.");
    }

    public DBConnect(string connectionString)
    {
        _connectionString = connectionString ?? throw new ArgumentNullException(nameof(connectionString));
    }

    /// <summary>
    /// Gets the configured database connection string.
    /// </summary>
    public string ConnectionString => _connectionString;

    /// <summary>
    /// Creates a new, closed SqlConnection.
    /// </summary>
    public SqlConnection CreateConnection()
    {
        return new SqlConnection(_connectionString);
    }

    /// <summary>
    /// Creates and asynchronously opens a new SqlConnection.
    /// </summary>
    public async Task<SqlConnection> CreateOpenConnectionAsync(CancellationToken cancellationToken = default)
    {
        var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync(cancellationToken);
        return connection;
    }

    /// <summary>
    /// Common method to execute any stored procedure and return the result set as a DataTable.
    /// Parameters are procedure name, procedure parameters, and optional command timeout and cancellation token.
    /// Any Output or InputOutput parameters passed in will be populated with their return values.
    /// </summary>
    /// <param name="procedureName">The name of the stored procedure to execute.</param>
    /// <param name="procedureParameters">Optional collection of SqlParameters (input, output, or return value).</param>
    /// <param name="commandTimeout">Optional command timeout in seconds.</param>
    /// <param name="cancellationToken">Optional cancellation token.</param>
    /// <returns>A DataTable containing any rows returned by the procedure.</returns>
    public async Task<DataTable> ExecuteProcedureAsync(
        string procedureName,
        IEnumerable<SqlParameter>? procedureParameters = null,
        int? commandTimeout = null,
        CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(procedureName))
            throw new ArgumentException("Procedure name cannot be null or empty.", nameof(procedureName));

        var dataTable = new DataTable();

        await using var connection = await CreateOpenConnectionAsync(cancellationToken);
        await using var command = new SqlCommand(procedureName, connection)
        {
            CommandType = CommandType.StoredProcedure
        };

        if (commandTimeout.HasValue)
        {
            command.CommandTimeout = commandTimeout.Value;
        }

        if (procedureParameters != null)
        {
            foreach (var parameter in procedureParameters)
            {
                command.Parameters.Add(parameter);
            }
        }

        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        dataTable.Load(reader);

        return dataTable;
    }

    /// <summary>
    /// Executes a stored procedure with procedure name, procedure parameters, and any other parameters if any.
    /// </summary>
    public Task<DataTable> ExecuteProcedure(
        string procedureName,
        IEnumerable<SqlParameter>? procedureParameters = null,
        int? commandTimeout = null,
        CancellationToken cancellationToken = default) =>
        ExecuteProcedureAsync(procedureName, procedureParameters, commandTimeout, cancellationToken);
}
