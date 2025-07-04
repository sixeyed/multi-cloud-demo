using System.ComponentModel.DataAnnotations;

namespace MultiCloudDemo.Shared.Models;

public class Message
{
    [Key]
    public int Id { get; set; }
    
    public string Content { get; set; } = string.Empty;
    
    public DateTime ProcessedAt { get; set; } = DateTime.UtcNow;
}