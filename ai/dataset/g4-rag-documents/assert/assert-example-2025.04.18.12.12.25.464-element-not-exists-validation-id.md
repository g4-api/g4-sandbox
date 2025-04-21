### Element Not Exists Validation Using Id

This example demonstrates how the Assert plugin verifies that an element with the Id `username` does not exist in the DOM.  
If the element is absent, the assert evaluates to `true`.

- **Rule Purpose**: Check that an element with the specified Id is not present in the page  
- **Type**: Action  
- **Argument**: Check if an element does not exist  
  - **Parameters**:  
    - **Condition**: ElementNotExists - Verifies that the specified element is not found in the DOM  
- **Locator**: Id  
- **On Element**: username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotExists}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
