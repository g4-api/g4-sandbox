### Session to User Parameter Copy Action

User scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the session parameter `SourceParam` and stores it into a user-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists and the user-scoped target parameter can be written; otherwise, it fails.

- **Rule Purpose**: Copy the full text from a session parameter to a user-scoped parameter without modification  
- **Type**: Action  
- **Argument**: Copy parameter value from session to user scope  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the user-scoped parameter to receive the value  
    - **TargetScope**: User - Specifies that the target parameter is user-scoped  
- **On Attribute**: Session  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:User}}",
  "onAttribute": "Session",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
