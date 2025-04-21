### Element Disabled Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#username` is disabled.  
If the element is disabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element identified by the CSS selector #username is disabled  
- **Type**: Action  
- **Argument**: Check if an element is disabled  
  - **Parameters**:  
    - **Condition**: ElementDisabled - Verifies that the specified element is disabled  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementDisabled}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
