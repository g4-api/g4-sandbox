### Element Exists Validation Using Xpath

This example demonstrates how the Assert plugin verifies that an element identified by the Xpath selector `//input[@id='username']` exists in the DOM.  
If the element exists, the assert evaluates to `true`.

- **Rule Purpose**: Check if an element identified by the given Xpath exists in the page DOM  
- **Type**: Action  
- **Argument**: Check if an element exists  
  - **Parameters**:  
    - **Condition**: ElementExists - Verifies presence of a specified element in the DOM  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementExists}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
