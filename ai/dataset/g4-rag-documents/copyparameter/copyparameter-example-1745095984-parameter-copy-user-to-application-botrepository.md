### User to Application Parameter Copy Action in BotRepository

User scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the user-scoped parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the application-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a user-scoped parameter to an application-scoped parameter in the BotRepository environment  
- **Type**: Action  
- **Argument**: macro... Copy user parameter text to application parameter  
- **On Attribute**: User  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Application}}",
  "onAttribute": "User",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
