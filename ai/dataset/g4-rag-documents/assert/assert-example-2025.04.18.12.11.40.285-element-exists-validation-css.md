### Element Exists Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that an element identified by the CSS selector `#username` exists in the DOM.  
If the element exists, the assert evaluates to `true`.

- **Rule Purpose**: Check if an element with the CSS selector #username exists on the page  
- **Type**: Action  
- **Argument**: Check if an element exists  
  - **Parameters**:  
    - **Condition**: ElementExists - Verifies presence of a specified element in the DOM  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementExists}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
