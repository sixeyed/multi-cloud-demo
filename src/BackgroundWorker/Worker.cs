using MultiCloudDemo.Shared.Data;
using MultiCloudDemo.Shared.Models;
using StackExchange.Redis;

namespace BackgroundWorker;

public class Worker(ILogger<Worker> logger, IConnectionMultiplexer redis, IServiceProvider serviceProvider) : BackgroundService
{
    private readonly ILogger<Worker> _logger = logger;
    private readonly IConnectionMultiplexer _redis = redis;
    private readonly IServiceProvider _serviceProvider = serviceProvider;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var db = _redis.GetDatabase();
        
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                var message = await db.ListRightPopAsync("messages");
                
                if (message.HasValue)
                {
                    _logger.LogInformation("Received message: {message}", message);
                    
                    using var scope = _serviceProvider.CreateScope();
                    var dbContext = scope.ServiceProvider.GetRequiredService<MessageDbContext>();
                    
                    var messageEntity = new Message
                    {
                        Content = message.ToString(),
                        ProcessedAt = DateTime.UtcNow
                    };
                    
                    dbContext.Messages.Add(messageEntity);
                    await dbContext.SaveChangesAsync(stoppingToken);
                    
                    _logger.LogInformation("Message saved to database with ID: {id}", messageEntity.Id);
                }
                else
                {
                    await Task.Delay(1000, stoppingToken);
                }
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error processing message");
                await Task.Delay(5000, stoppingToken);
            }
        }
    }
}
