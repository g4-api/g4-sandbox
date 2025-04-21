### Element Text Length NotMatch Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed length of the visible text of the element identified by the CSS selector `#content` does not match the pattern `^2\d+$`.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length, when converted to a string, does not begin with the digit '2'.

- **Rule Purpose**: Verify that the visible text length of the element does not start with the digit '2'  
- **Type**: Action  
- **Argument**: Check that element text length does not match a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Uses the length of the visible text of the element  
    - **Operator**: NotMatch - The length must not match the expected pattern  
    - **Expected**: ^2\d+$ - The pattern to check against, meaning length starts with '2' followed by digits  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^2\\d+$}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
