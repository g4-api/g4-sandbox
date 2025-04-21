### Session to Application Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the session parameter `SourceParam` and stores it into an application-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the application-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a session parameter to an application-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy parameter value from session to application scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the target parameter to receive the copied value  
    - **TargetScope**: Application - The scope where the target parameter is stored  
- **On Attribute**: Session  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Application}}",
  "onAttribute": "Session",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
