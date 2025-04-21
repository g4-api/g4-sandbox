### Element Not Active Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='username']` is not active.  
If the element is not active, the assert evaluates to `true`.

- **Rule Purpose**: Check that the specified element is not currently active  
- **Type**: Action  
- **Argument**: Check if the element is not active  
  - **Parameters**:  
    - **Condition**: ElementNotActive - Verifies that the element is not focused or active  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotActive}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
