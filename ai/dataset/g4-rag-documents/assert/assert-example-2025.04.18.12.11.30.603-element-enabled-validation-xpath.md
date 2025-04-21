### Element Enabled Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='username']` is enabled.  
If the element is enabled, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element located by the given Xpath is enabled  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is enabled  
  - **Parameters**:  
    - **Condition**: ElementEnabled - Verifies that the specified element is enabled  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementEnabled}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
