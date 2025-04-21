### Application to Machine Parameter Copy Action

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into a machine-scoped parameter named `TargetParam` in the default application environment `SystemParameters`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the machine-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from an application-scoped parameter to a machine-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from application scope to machine scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the machine-scoped parameter to write  
    - **TargetScope**: Machine - Specifies that the target parameter is machine-scoped  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Machine}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
