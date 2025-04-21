### Application to User Parameter Copy Action in BotRepository

User scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into a user-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the user-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from an application-scoped parameter to a user-scoped parameter in the BotRepository environment  
- **Type**: Action  
- **Argument**: Copy parameter TargetParam to user scope in BotRepository environment  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the target parameter to copy to  
    - **Environment**: BotRepository - The environment where the target parameter is stored  
    - **TargetScope**: User - The scope of the target parameter  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:User}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
