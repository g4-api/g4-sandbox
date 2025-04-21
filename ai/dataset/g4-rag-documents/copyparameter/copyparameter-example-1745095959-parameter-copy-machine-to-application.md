### Machine to Application Parameter Copy Action

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the machine-scoped parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam` in the default application environment `SystemParameters`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text value from a machine-scoped parameter to an application-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from machine scope to application scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to store the copied value into  
    - **TargetScope**: Application - The scope where the target parameter is stored  
- **On Attribute**: Machine  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Application}}",
  "onAttribute": "Machine",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
