using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using StackExchange.Redis;

namespace WebApp.Pages;

public class IndexModel : PageModel
{
    private readonly IConnectionMultiplexer _redis;
    
    public IndexModel(IConnectionMultiplexer redis)
    {
        _redis = redis;
    }
    
    public string RandomMessage { get; set; } = string.Empty;
    
    [BindProperty]
    public string Message { get; set; } = string.Empty;
    
    public void OnGet()
    {
        RandomMessage = GenerateRandomMessage();
    }
    
    public async Task<IActionResult> OnPostAsync()
    {
        if (!string.IsNullOrEmpty(Message))
        {
            var db = _redis.GetDatabase();
            await db.ListLeftPushAsync("messages", Message);
        }
        
        return RedirectToPage();
    }
    
    private static string GenerateRandomMessage()
    {
        var adjectives = new[] { "Amazing", "Fantastic", "Incredible", "Awesome", "Brilliant", "Superb", "Outstanding", "Excellent" };
        var nouns = new[] { "Kubernetes", "Container", "Microservice", "Application", "System", "Platform", "Service", "Deployment" };
        var verbs = new[] { "rocks", "rules", "shines", "delivers", "performs", "scales", "works", "succeeds" };
        
        var random = new Random();
        var adjective = adjectives[random.Next(adjectives.Length)];
        var noun = nouns[random.Next(nouns.Length)];
        var verb = verbs[random.Next(verbs.Length)];
        var timestamp = DateTime.Now.ToString("HH:mm:ss");
        
        return $"{adjective} {noun} {verb} at {timestamp}";
    }
}