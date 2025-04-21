### Application to Machine Parameter Copy Action in BotRepository

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into a machine-scoped parameter named `TargetParam` within the `BotRepository` environment.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the machine-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text value from an application-scoped parameter to a machine-scoped parameter in the BotRepository environment  
- **Type**: Action  
- **Argument**: Copy parameter with specified target, environment, and scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the target parameter to write to  
    - **Environment**: BotRepository - The environment where the target parameter is stored  
    - **TargetScope**: Machine - The scope of the target parameter, valid only on Windows  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --Environment:BotRepository --TargetScope:Machine}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
