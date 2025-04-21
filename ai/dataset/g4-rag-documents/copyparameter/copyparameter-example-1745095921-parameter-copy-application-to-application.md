### Application to Application Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into another application-scoped parameter named `TargetParam` in the default application environment `SystemParameters`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from one application-scoped parameter to another without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from source to target within the application scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to receive the copied value  
    - **TargetScope**: Application - The scope where the target parameter is located  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Application}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
