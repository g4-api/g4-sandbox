### Element Active Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specific element is active.  
The condition `ElementActive` is applied to the element identified by the Xpath selector `//*[@id='ElementActive']`.  
If the element is active, the assert evaluates to `true`.

- **Rule Purpose**: Check if a specific element identified by Xpath is currently active  
- **Type**: Action  
- **Argument**: Check if a specific element is active  
  - **Parameters**:  
    - **Condition**: ElementActive - Verifies that the targeted element is active or focused  
- **Locator**: Xpath  
- **On Element**: //*[@id='ElementActive']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementActive}}",
  "locator": "Xpath",
  "onElement": "//*[@id='ElementActive']",
  "pluginName": "Assert"
}
```
