### Element Text Length Match Validation Using Id

This example demonstrates how the Assert plugin verifies that the visible text of the element with the Id `content` has a length that matches the regular expression pattern `^2\d+$`.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The regular expression is used to confirm that the computed length (converted to a string) starts with the digit 2 followed by one or more digits.  
The assertion passes only if the computed length exactly matches this pattern.

- **Rule Purpose**: Verify that the visible text length of the element with Id "content" matches a pattern starting with 2 followed by digits  
- **Type**: Action  
- **Argument**: Check if element text length matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Match - Uses a regular expression match for comparison  
    - **Expected**: ^2\d+$ - The expected pattern for the text length as a string  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^2\\d+$}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
