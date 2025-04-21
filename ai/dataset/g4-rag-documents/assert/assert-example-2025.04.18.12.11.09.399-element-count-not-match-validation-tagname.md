### Element Count NotMatch Regex Validation Using TagName

This example demonstrates how the Assert plugin verifies that the element count for elements with the tag name `button` is strictly numeric by confirming the absence of alphabetic characters.  
It asserts that the element count does not match the regex pattern `.*[a-zA-Z]+.*` using the NotMatch operator.  
If the element count is strictly numeric, the assert evaluates to `true`.

- **Rule Purpose**: Check that the count of button elements does not contain any letters, ensuring it is strictly numeric  
- **Type**: Action  
- **Argument**: Verify element count does not match alphabetic pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of matching elements  
    - **Operator**: NotMatch - Ensures the count does not match the given pattern  
    - **Expected**: .*[a-zA-Z]+.* - The regex pattern for alphabetic characters  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotMatch --Expected:.*[a-zA-Z]+.*}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
