### Element Selected Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `acceptTerms` is selected.  
The ElementSelected condition only applies to elements such as `<input type="checkbox">`, `<input type="radio">`, or `<option selected>`.  
If the element is selected, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element with the specified Id is selected  
- **Type**: Action  
- **Argument**: Check if an element is selected  
  - **Parameters**:  
    - **Condition**: ElementSelected - Verifies that the element is currently selected (e.g., checkbox, radio button, or option)  
- **Locator**: Id  
- **On Element**: acceptTerms  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementSelected}}",
  "locator": "Id",
  "onElement": "acceptTerms",
  "pluginName": "Assert"
}
```
