### Element Text Length NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed length of the visible text of the element identified by the Xpath selector `//div[@id='content']` does not match the pattern `^2\d+$`.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length, when converted to a string, does not begin with the digit '2'.

- **Rule Purpose**: Verify that the visible text length of a specific element does not match a pattern starting with '2'  
- **Type**: Action  
- **Argument**: Check that element text length does not match pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Uses the length of the visible text of the element  
    - **Operator**: NotMatch - The length must not match the expected pattern  
    - **Expected**: ^2\d+$ - The pattern to check against, matching lengths starting with '2'  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^2\\d+$}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
