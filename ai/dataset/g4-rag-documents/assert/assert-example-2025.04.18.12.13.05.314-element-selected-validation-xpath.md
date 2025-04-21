### Element Selected Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='acceptTerms']` is selected.  
The ElementSelected condition only applies to elements such as `<input type="checkbox">`, `<input type="radio">`, or `<option selected>`.  
If the element is selected, the assert evaluates to `true`.

- **Rule Purpose**: Check if the specified element is selected (e.g., checkbox, radio button, or option).  
- **Type**: Action  
- **Argument**: Check if the element is selected  
  - **Parameters**:  
    - **Condition**: ElementSelected - Verifies that the element is currently selected  
- **Locator**: Xpath  
- **On Element**: //input[@id='acceptTerms']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementSelected}}",
  "locator": "Xpath",
  "onElement": "//input[@id='acceptTerms']",
  "pluginName": "Assert"
}
```
