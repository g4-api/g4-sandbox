### Element Not Active Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `username` is not active.  
If the element is not active, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element with the specified Id is not currently active  
- **Type**: Action  
- **Argument**: Check if an element is not active  
  - **Parameters**:  
    - **Condition**: ElementNotActive - Verifies that the specified element is not active or focused  
- **Locator**: Id  
- **On Element**: username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotActive}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
