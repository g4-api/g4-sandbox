### Element Not Exists Validation Using Xpath

This example demonstrates how the Assert plugin verifies that an element identified by the Xpath selector `//input[@id='username']` does not exist in the DOM.  
If the element is absent, the assert evaluates to `true`.

- **Rule Purpose**: Check that an element with the specified Xpath does not exist in the page DOM  
- **Type**: Action  
- **Argument**: Check if an element does not exist  
  - **Parameters**:  
    - **Condition**: ElementNotExists - Verifies that the specified element is not present in the DOM  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotExists}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
