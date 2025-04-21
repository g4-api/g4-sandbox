### Element Visible Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that an element identified by the CSS selector `#username` is visible in the DOM.  
Visibility is determined solely based on the element's presence and rendering state, excluding any hidden or collapsed styling.  
The assertion passes if the element is visible; otherwise, it fails.

- **Rule Purpose**: Check if the element identified by the CSS selector #username is visible on the page  
- **Type**: Action  
- **Argument**: Check if an element is visible  
  - **Parameters**:  
    - **Condition**: ElementVisible - Verifies that the specified element is present and visible in the DOM  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementVisible}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
