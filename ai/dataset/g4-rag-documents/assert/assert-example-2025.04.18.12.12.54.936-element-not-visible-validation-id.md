### Element Not Visible Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `username` is not visible in the DOM.  
Visibility may be determined by properties such as `display: none`, `visibility: hidden`, or off-screen positioning.  
If the element is not visible, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element with the specified Id is not visible on the page  
- **Type**: Action  
- **Argument**: Check if an element is not visible  
  - **Parameters**:  
    - **Condition**: ElementNotVisible - Verifies that the element is hidden or not visible in the DOM  
- **Locator**: Id  
- **On Element**: username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotVisible}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
