### Element Count GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the number of elements matching the CSS selector `.primary-button` is greater than or equal to 2.  
If the element count is greater than or equal to 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that there are at least 2 elements matching the CSS selector `.primary-button`.  
- **Type**: Action  
- **Argument**: Verify element count is greater or equal to expected number  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: GreaterEqual - Compares if the count is greater than or equal to the expected value  
    - **Expected**: 2 - The minimum number of elements required  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:GreaterEqual --Expected:2}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
