### Element Disabled Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `username` is disabled.  
If the element is disabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element identified by Id 'username' is disabled  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is disabled  
  - **Parameters**:  
    - **Condition**: ElementDisabled - Verifies that the specified element is disabled  
- **Locator**: Id  
- **On Element**: username  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementDisabled}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
