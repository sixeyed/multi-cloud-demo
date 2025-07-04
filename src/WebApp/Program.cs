using StackExchange.Redis;
using Microsoft.EntityFrameworkCore;
using MultiCloudDemo.Shared.Data;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddRazorPages(options =>
{
    // Disable antiforgery tokens for this basic demo
    options.Conventions.ConfigureFilter(new Microsoft.AspNetCore.Mvc.IgnoreAntiforgeryTokenAttribute());
});

builder.Services.AddSingleton<IConnectionMultiplexer>(provider =>
{
    var connectionString = builder.Configuration.GetConnectionString("Redis") ?? "localhost:6379";
    return ConnectionMultiplexer.Connect(connectionString);
});

builder.Services.AddDbContext<MessageDbContext>(options =>
{
    var connectionString = builder.Configuration.GetConnectionString("SqlServer") ?? 
                          "Server=localhost,1433;Database=MultiCloudDemo;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=true;";
    options.UseSqlServer(connectionString);
});

var app = builder.Build();

// Initialize database (first service to start will create it)
var logger = app.Services.GetRequiredService<ILogger<Program>>();
var initialized = await DatabaseInitializer.InitializeDatabaseAsync(app.Services, logger);

if (!initialized)
{
    logger.LogWarning("Database initialization failed, but continuing as BackgroundWorker may initialize it");
}

app.UseRouting();
app.MapRazorPages();

app.Run();