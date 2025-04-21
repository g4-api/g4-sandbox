### User to Session Parameter Copy Action

User scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the user-scoped parameter `SourceParam` and stores it into a session-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a user-scoped parameter to a session-scoped parameter without modification  
- **Type**: Action  
- **Argument**: Copy parameter value from user scope to session scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the parameter to store the copied value  
    - **TargetScope**: Session - The scope where the target parameter is stored  
- **On Attribute**: User  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:Session}}",
  "onAttribute": "User",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
