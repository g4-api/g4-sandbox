### Element Count Regex Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element count for the Xpath selector `//button` matches the regex pattern `^[1-9][0-9]*$`.  
It asserts that the element count is a positive integer using the Match operator.  
If the element count matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of elements found by the Xpath selector is a positive integer matching the given regex pattern  
- **Type**: Action  
- **Argument**: Verify element count matches a regex pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: Match - Uses regex matching for the count  
    - **Expected**: ^[1-9][0-9]*$ - The regex pattern for a positive integer  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Match --Expected:^[1-9][0-9]*$}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
