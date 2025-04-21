### Element Enabled Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `username` is enabled.  
If the element is enabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element with the specified Id is enabled  
- **Type**: Action  
- **Argument**: Check if an element is enabled  
  - **Parameters**:  
    - **Condition**: ElementEnabled - Verifies that the targeted element is enabled and interactive  
- **Locator**: Id  
- **On Element**: username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementEnabled}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
