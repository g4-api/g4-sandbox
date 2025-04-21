### Application to Session Parameter Copy Action

This example demonstrates how the CopyParameter plugin takes the full text value of the application-scoped parameter `SourceParam` and stores it into a session-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from an application-scoped parameter to a session-scoped parameter without changes  
- **Type**: Action  
- **Argument**: Copy a parameter value from application scope to session scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the session-scoped parameter to receive the copied value  
    - **TargetScope**: Session - The scope where the target parameter is stored  
- **On Attribute**: Application  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Session}}",
  "onAttribute": "Application",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
