### Element Exists Validation Using Id

This example demonstrates how the Assert plugin verifies that an element with the Id `username` exists in the DOM.  
If the element exists, the assert evaluates to `true`.

- **Rule Purpose**: Check if an element with the specified Id exists on the page  
- **Type**: Action  
- **Argument**: Check if an element exists  
  - **Parameters**:  
    - **Condition**: ElementExists - Verifies that the specified element is present in the DOM  
- **Locator**: Id  
- **On Element**: username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementExists}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
