### Application to Application Parameter Copy Action in BotRepository

This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the target environment is valid; otherwise, it fails.

- **Rule Purpose**: Copy the full text value from one application-scoped parameter to another within a specified environment.  
- **Type**: Action  
- **Argument**: Copy full text from source to target parameter in BotRepository environment  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to receive the copied value  
    - **Environment**: BotRepository - The environment where the target parameter is located  
    - **TargetScope**: Application - The scope of the target parameter within the environment  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Application}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
