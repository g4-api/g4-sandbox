### Element Count NotMatch Regex Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element count for the Xpath selector `//button` is strictly numeric by confirming the absence of alphabetic characters.  
It asserts that the element count does not match the regex pattern `.*[a-zA-Z]+.*` using the NotMatch operator.  
If the element count is strictly numeric, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element count for the given XPath selector does not contain alphabetic characters  
- **Type**: Action  
- **Argument**: Verify element count does not match alphabetic regex pattern  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the count of elements matching the locator  
    - **Operator**: NotMatch - Ensures the count does not match the given pattern  
    - **Expected**: .*[a-zA-Z]+.* - Regex pattern to detect alphabetic characters  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotMatch --Expected:.*[a-zA-Z]+.*}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
