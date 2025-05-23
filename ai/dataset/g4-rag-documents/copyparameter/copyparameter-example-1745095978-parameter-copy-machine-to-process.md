### Machine to Process Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the machine-scoped parameter `SourceParam` and stores it into a process-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a machine-scoped parameter to a process-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from machine scope to process scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to receive the copied value  
    - **TargetScope**: Process - The scope where the target parameter is stored  
- **On Attribute**: Machine  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Process}}",
  "onAttribute": "Machine",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
