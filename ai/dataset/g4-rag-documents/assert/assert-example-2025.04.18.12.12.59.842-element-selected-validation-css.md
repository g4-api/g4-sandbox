### Element Selected Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#acceptTerms` is selected.  
The ElementSelected condition only applies to elements such as `<input type="checkbox">`, `<input type="radio">`, or `<option selected>`.  
If the element is selected, the assert evaluates to `true`.

- **Rule Purpose**: Check if the specified element is selected  
- **Type**: Action  
- **Argument**: Check if the element is selected  
  - **Parameters**:  
    - **Condition**: ElementSelected - Verifies that the element is currently selected (checkbox, radio button, or option)  
- **Locator**: CssSelector  
- **On Element**: #acceptTerms  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementSelected}}",
  "locator": "CssSelector",
  "onElement": "#acceptTerms",
  "pluginName": "Assert"
}
```
