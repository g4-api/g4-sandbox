### Element Not Selected Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `acceptTerms` is not selected.  
If the element is not selected, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element with the specified Id is not selected  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is not selected  
  - **Parameters**:  
    - **Condition**: ElementNotSelected - Verifies that the target element is not currently selected  
- **Locator**: Id  
- **On Element**: acceptTerms  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementNotSelected}}",
  "locator": "Id",
  "onElement": "acceptTerms",
  "pluginName": "Assert"
}
```
