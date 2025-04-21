### Element Count Regex Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element count for the selector `.primary-button` matches the regex pattern `^[1-9][0-9]*$`.  
It asserts that the element count is a positive integer using the Match operator.  
If the element count matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of elements matching `.primary-button` is a positive integer  
- **Type**: Action  
- **Argument**: Verify element count matches a regex pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: Match - Uses regex matching for the count  
    - **Expected**: ^[1-9][0-9]*$ - The regex pattern for a positive integer  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Match --Expected:^[1-9][0-9]*$}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
