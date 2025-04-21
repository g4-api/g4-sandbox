### Application to Process Parameter Copy Action in BotRepository

This example demonstrates how the CopyParameter plugin takes the full text value of the application�??scoped parameter `SourceParam` and stores it into a process�??scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as�??is.  
The action succeeds only if `SourceParam` exists and the process�??scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from an application-scoped parameter to a process-scoped parameter in a specified environment  
- **Type**: Action  
- **Argument**: macro... Copy full text from source to target parameter without transformation  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Process}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
