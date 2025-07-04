using BackgroundWorker;
using MultiCloudDemo.Shared.Data;
using Microsoft.EntityFrameworkCore;
using StackExchange.Redis;

var builder = Host.CreateApplicationBuilder(args);

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

builder.Services.AddHostedService<Worker>();

var host = builder.Build();

var logger = host.Services.GetRequiredService<ILogger<Program>>();
var initialized = await DatabaseInitializer.InitializeDatabaseAsync(host.Services, logger);

if (!initialized)
{
    logger.LogError("Failed to initialize database. Exiting...");
    Environment.Exit(1);
}

host.Run();
