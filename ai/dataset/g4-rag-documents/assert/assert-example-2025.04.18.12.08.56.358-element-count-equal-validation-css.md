### Element Count Equal Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the number of elements matching the CSS selector `.primary-button` is exactly 2.  
If the element count equals 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that exactly two elements match the given CSS selector  
- **Type**: Action  
- **Argument**: Verify element count equals 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of matching elements  
    - **Operator**: Equal - Compares if the count is equal to the expected number  
    - **Expected**: 2 - The exact number of elements expected  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Equal --Expected:2}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
