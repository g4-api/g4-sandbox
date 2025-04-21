### Element Count Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the number of elements matching the CSS selector `.primary-button` is greater than 2.  
If the element count exceeds 2, the assert evaluates to `true`.

- **Rule Purpose**: Check if more than 2 elements match the CSS selector `.primary-button`  
- **Type**: Action  
- **Argument**: Check if element count is greater than 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Counts elements matching the locator  
    - **Operator**: Greater - Checks if count is greater than expected  
    - **Expected**: 2 - The number to compare the element count against  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Greater --Expected:2}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
