### Element Active Validation Using Id

This example demonstrates how the Assert plugin verifies that a specific element is active using the Id locator.  
It asserts that the condition `ElementActive` is applied to the element with the Id `ElementActive`.  
If the element is active, the assert evaluates to `true`.

- **Rule Purpose**: Check if a specific element identified by Id is currently active  
- **Type**: Action  
- **Argument**: Check if an element is active  
  - **Parameters**:  
    - **Condition**: ElementActive - Verifies that the targeted element is currently active or focused  
- **Locator**: Id  
- **On Element**: ElementActive  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementActive}}",
  "locator": "Id",
  "onElement": "ElementActive",
  "pluginName": "Assert"
}
```
