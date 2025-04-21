### Element Not Exists Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that an element identified by the CSS selector `#username` does not exist in the DOM.  
If the element is absent, the assert evaluates to `true`.

- **Rule Purpose**: Check that an element with the CSS selector #username is not present in the DOM  
- **Type**: Action  
- **Argument**: Check if an element does not exist  
  - **Parameters**:  
    - **Condition**: ElementNotExists - Verifies that the specified element is not found in the page  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotExists}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
