### Machine to Machine Parameter Copy Action

Machine scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the machine-scoped parameter `SourceParam` and stores it into another machine-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text value from one machine-scoped parameter to another without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from source to target on machine scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to receive the copied value  
    - **TargetScope**: Machine - The scope where the target parameter is stored  
- **On Attribute**: Machine  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Machine}}",
  "onAttribute": "Machine",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
