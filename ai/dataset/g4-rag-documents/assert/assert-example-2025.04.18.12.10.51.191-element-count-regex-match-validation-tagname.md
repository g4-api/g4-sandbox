### Element Count Regex Match Validation Using TagName

This example demonstrates how the Assert plugin verifies that the element count for elements with the tag name `button` matches the regex pattern `^[1-9][0-9]*$`.  
It asserts that the element count is a positive integer using the Match operator.  
If the element count matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of button elements matches a positive integer pattern  
- **Type**: Action  
- **Argument**: Verify element count matches regex pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the count of elements found  
    - **Operator**: Match - Uses regex matching for validation  
    - **Expected**: ^[1-9][0-9]*$ - Regex pattern for positive integers  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Match --Expected:^[1-9][0-9]*$}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
