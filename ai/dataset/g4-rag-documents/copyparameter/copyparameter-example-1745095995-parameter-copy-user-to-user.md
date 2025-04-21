### User to User Parameter Copy Action

User scopes are only valid on Windows environments.  
This example demonstrates how the CopyParameter plugin takes the full text value of the user-scoped parameter `SourceParam` and stores it into another user-scoped parameter named `TargetParam`.  
The operation uses the complete text value of `SourceParam`, including any whitespace or formatting.  
No value transformation occurs; the entire text is copied as-is.  
The action succeeds only if `SourceParam` exists; otherwise, it fails.

- **Rule Purpose**: Copy the full text from one user-scoped parameter to another without changes  
- **Type**: Action  
- **Argument**: Copy user-scoped parameter value from SourceParam to TargetParam  
  - **Parameters**:  
    - **TargetParameter**: TargetParam - The name of the user-scoped parameter to receive the copied value  
    - **TargetScope**: User - Specifies that the target parameter is user-scoped  
- **On Attribute**: User  
- **On Element**: SourceParam  
- **Plugin Name**: CopyParameter  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --TargetParameter:TargetParam --TargetScope:User}}",
  "onAttribute": "User",
  "onElement": "SourceParam",
  "pluginName": "CopyParameter"
}
```
