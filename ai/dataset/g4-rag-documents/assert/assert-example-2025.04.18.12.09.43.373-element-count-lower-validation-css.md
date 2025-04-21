### Element Count Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the number of elements matching the CSS selector `.primary-button` is lower than 2.  
If the element count is less than 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that fewer than 2 elements match the CSS selector `.primary-button`  
- **Type**: Action  
- **Argument**: Verify element count is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of matching elements  
    - **Operator**: Lower - Compares if the count is less than the expected value  
    - **Expected**: 2 - The threshold number of elements to compare against  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Lower --Expected:2}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
