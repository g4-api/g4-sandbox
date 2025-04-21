### Element Not Selected Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='acceptTerms']` is not selected.  
If the element is not selected, the assert evaluates to `true`.

- **Rule Purpose**: Check that the specified element is not selected  
- **Type**: Action  
- **Argument**: Check if an element is not selected  
  - **Parameters**:  
    - **Condition**: ElementNotSelected - Verifies that the targeted element is currently not selected  
- **Locator**: Xpath  
- **On Element**: //input[@id='acceptTerms']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotSelected}}",
  "locator": "Xpath",
  "onElement": "//input[@id='acceptTerms']",
  "pluginName": "Assert"
}
```
