### Element Text Length NotMatch Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed length of the visible text of the element with the Id `content` does not match the pattern `^2\d+$`.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length, when converted to a string, does not begin with the digit '2'.

- **Rule Purpose**: Check that the visible text length of the element with Id 'content' does not start with the digit 2  
- **Type**: Action  
- **Argument**: Validate that element text length does not match a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Uses the length of the visible text of the element  
    - **Operator**: NotMatch - The length string should not match the given pattern  
    - **Expected**: ^2\d+$ - Pattern that matches strings starting with digit 2 followed by digits  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^2\\d+$}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
