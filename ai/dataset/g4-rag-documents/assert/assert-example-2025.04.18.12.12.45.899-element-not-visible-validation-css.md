### Element Not Visible Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#username` is not visible in the DOM.  
Visibility may be determined by properties such as `display: none`, `visibility: hidden`, or off-screen positioning.  
If the element is not visible, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element identified by the CSS selector #username is not visible on the page  
- **Type**: Action  
- **Argument**: Check if an element is not visible  
  - **Parameters**:  
    - **Condition**: ElementNotVisible - Verifies that the element is hidden or not visible in the DOM  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotVisible}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
