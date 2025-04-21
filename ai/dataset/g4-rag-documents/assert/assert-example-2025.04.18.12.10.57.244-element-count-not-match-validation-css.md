### Element Count NotMatch Regex Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element count for the selector `.primary-button` is strictly numeric by confirming the absence of alphabetic characters.  
It asserts that the element count does not match the regex pattern `.*[a-zA-Z]+.*` using the NotMatch operator.  
If the element count is strictly numeric, the assert evaluates to `true`.

- **Rule Purpose**: Check that the count of elements matching `.primary-button` does not contain letters  
- **Type**: Action  
- **Argument**: Verify element count does not match alphabetic pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of elements found  
    - **Operator**: NotMatch - Ensures the count does not match the pattern  
    - **Expected**: .*[a-zA-Z]+.* - The regex pattern to exclude alphabetic characters  
- **Locator**: CssSelector  
- **On Element**: .primary-button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotMatch --Expected:.*[a-zA-Z]+.*}}",
  "locator": "CssSelector",
  "onElement": ".primary-button",
  "pluginName": "Assert"
}
```
