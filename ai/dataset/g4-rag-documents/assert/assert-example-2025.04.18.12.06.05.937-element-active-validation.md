### Element Active Validation

This example demonstrates how the Assert plugin verifies that a specific element is active.  
The condition `ElementActive` is applied to the element identified by the CSS selector `#ElementActive`.  
If the element is active, the assert evaluates to `true`.

- **Rule Purpose**: Check if a specific element is currently active on the page  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if a specific element is active  
  - **Parameters**:  
    - **Condition**: ElementActive - Verifies that the targeted element has focus or is active  
- **Locator**: CssSelector  
- **On Element**: #ElementActive  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementActive}}",
  "locator": "CssSelector",
  "onElement": "#ElementActive",
  "pluginName": "Assert"
}
```
