### Element Count NotEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the number of elements matching the CSS selector `.primary-button` is not equal to 2.  
If the element count is different from 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of elements matching the selector is not equal to 2  
- **Type**: Action  
- **Argument**: Verify element count is not equal to 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: NotEqual - The count should not be equal to the expected number  
    - **Expected**: 2 - The number to compare the element count against  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotEqual --Expected:2}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
