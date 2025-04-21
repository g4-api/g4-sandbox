### Element Not Active Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#username` is not active.  
If the element is not active, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element with CSS selector #username is not currently active  
- **Type**: Action  
- **Argument**: Check if the element is not active  
  - **Parameters**:  
    - **Condition**: ElementNotActive - Verifies that the specified element is not the active element on the page  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotActive}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
