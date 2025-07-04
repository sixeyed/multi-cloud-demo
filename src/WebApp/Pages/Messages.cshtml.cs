using Microsoft.AspNetCore.Mvc.RazorPages;
using Microsoft.EntityFrameworkCore;
using MultiCloudDemo.Shared.Data;
using MultiCloudDemo.Shared.Models;

namespace WebApp.Pages;

public class MessagesModel : PageModel
{
    private readonly MessageDbContext _dbContext;
    
    public MessagesModel(MessageDbContext dbContext)
    {
        _dbContext = dbContext;
    }
    
    public List<Message> Messages { get; set; } = new();
    public string? ErrorMessage { get; set; }
    
    public async Task OnGetAsync()
    {
        try
        {
            Messages = await _dbContext.Messages
                .OrderByDescending(m => m.ProcessedAt)
                .Take(100)
                .ToListAsync();
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Unable to connect to database: {ex.Message}";
            Messages = new List<Message>();
        }
    }
}