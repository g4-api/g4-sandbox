### Element Enabled Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#username` is enabled.  
If the element is enabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element identified by the CSS selector #username is enabled  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is enabled  
  - **Parameters**:  
    - **Condition**: ElementEnabled - Verifies that the specified element is enabled and interactive  
- **Locator**: CssSelector  
- **On Element**: #username  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementEnabled}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
