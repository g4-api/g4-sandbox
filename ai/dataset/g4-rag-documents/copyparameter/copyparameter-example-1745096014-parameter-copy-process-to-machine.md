### Process to Machine Parameter Copy Action

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the process-scoped parameter `SourceParam` and stores it into a machine-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a process-scoped parameter to a machine-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from process scope to machine scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to store the copied value  
    - **TargetScope**: Machine - The scope where the target parameter is stored  
- **On Attribute**: Process  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Machine}}",
  "onAttribute": "Process",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
