### Element Disabled Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='username']` is disabled.  
If the element is disabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element located by Xpath is disabled  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is disabled  
  - **Parameters**:  
    - **Condition**: ElementDisabled - Verifies that the specified element is disabled  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementDisabled}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
