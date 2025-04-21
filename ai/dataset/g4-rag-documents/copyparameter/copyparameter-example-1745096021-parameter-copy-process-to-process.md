### Process to Process Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the process-scoped parameter `SourceParam` and stores it into another process-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from one process-scoped parameter to another without changes  
- **Type**: Action  
- **Argument**: Copy a parameter value from one process scope to another  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to receive the copied value  
    - **TargetScope**: Process - The scope where the target parameter is located  
- **On Attribute**: Process  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Process}}",
  "onAttribute": "Process",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
