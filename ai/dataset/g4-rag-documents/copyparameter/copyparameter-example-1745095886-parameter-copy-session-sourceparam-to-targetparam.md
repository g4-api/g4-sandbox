### Session Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the session parameter `SourceParam` and stores it into another session parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from one session parameter to another without changes  
- **Type**: Action  
- **Argument**: Copy session parameter value from SourceParam to TargetParam  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the session parameter to store the copied value  
    - **TargetScope**: Session - The scope where the target parameter is stored  
- **On Attribute**: Session  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Session}}",
  "onAttribute": "Session",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
