### Element Visible Validation Using Xpath

This example demonstrates how the Assert plugin verifies that an element identified by the XPath locator `//input[@id='username']` is visible in the DOM.  
Visibility is determined solely based on the element's presence and rendering state, excluding any hidden or collapsed styling.  
The assertion passes if the element is visible; otherwise, it fails.

- **Rule Purpose**: Check if a specific element identified by XPath is visible on the page  
- **Type**: Action  
- **Argument**: Check if an element is visible  
  - **Parameters**:  
    - **Condition**: ElementVisible - Verifies that the element is present and rendered visible in the DOM  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementVisible}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
