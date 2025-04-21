### Element Not Visible Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='username']` is not visible in the DOM.  
Visibility may be determined by properties such as `display: none`, `visibility: hidden`, or off-screen positioning.  
If the element is not visible, the assert evaluates to `true`.

- **Rule Purpose**: Check that the specified element is not visible on the page  
- **Type**: Action  
- **Argument**: Verify element invisibility  
  - **Parameters**:  
    - **Condition**: ElementNotVisible - Checks if the element is hidden or not visible in the DOM  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotVisible}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
