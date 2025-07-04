using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace MultiCloudDemo.Shared.Data;

public static class DatabaseInitializer
{
    public static async Task<bool> InitializeDatabaseAsync(IServiceProvider serviceProvider, ILogger logger)
    {
        try
        {
            using var scope = serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<MessageDbContext>();
            
            logger.LogInformation("Attempting to connect to SQL Server...");
            
            // Test the connection first
            await context.Database.CanConnectAsync();
            logger.LogInformation("Successfully connected to SQL Server");
            
            // Ensure database and tables are created
            await context.Database.EnsureCreatedAsync();
            logger.LogInformation("Database schema ensured");
            
            return true;
        }
        catch (Exception ex)
        {
            logger.LogError(ex, "Failed to connect to SQL Server database");
            return false;
        }
    }
}