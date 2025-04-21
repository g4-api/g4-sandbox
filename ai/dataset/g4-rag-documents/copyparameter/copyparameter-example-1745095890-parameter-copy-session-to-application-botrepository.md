### Session to Application Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the session parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the application-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a session parameter to an application-scoped parameter in a specified environment  
- **Type**: Action  
- **Argument**: Copy parameter with specified target, environment, and scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the target parameter to receive the copied value  
    - **Environment**: BotRepository - The environment where the target parameter is stored  
    - **TargetScope**: Application - The scope of the target parameter  
- **On Attribute**: Session  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Application}}",
  "onAttribute": "Session",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
