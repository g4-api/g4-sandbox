### Machine to Application Parameter Copy Action in BotRepository

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the machine-scoped parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the application-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text value from a machine-scoped parameter to an application-scoped parameter in a specified environment.  
- **Type**: Action  
- **Argument**: Copy parameter value from machine scope to application scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the target parameter to write the value into  
    - **Environment**: BotRepository - The environment where the target parameter is located  
    - **TargetScope**: Application - The scope of the target parameter  
- **On Attribute**: Machine  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Application}}",
  "onAttribute": "Machine",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
