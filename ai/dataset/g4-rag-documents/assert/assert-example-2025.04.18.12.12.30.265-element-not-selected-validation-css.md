### Element Not Selected Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#acceptTerms` is not selected.  
If the element is not selected, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element identified by the CSS selector #acceptTerms is not selected  
- **Type**: Action  
- **Argument**: Check if an element is not selected  
  - **Parameters**:  
    - **Condition**: ElementNotSelected - Verifies that the specified element is not currently selected  
- **Locator**: CssSelector  
- **On Element**: #acceptTerms  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotSelected}}",
  "locator": "CssSelector",
  "onElement": "#acceptTerms",
  "pluginName": "Assert"
}
```
