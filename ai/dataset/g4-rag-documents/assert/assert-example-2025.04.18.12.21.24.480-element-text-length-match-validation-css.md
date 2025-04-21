### Element Text Length Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the CSS selector `#content` has a length that matches the regular expression pattern `^2\d+$`.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The regular expression is used to validate that the computed length (converted to a string) begins with the digit 2 and is followed by one or more digits.  
The assertion passes only if the computed length exactly matches this pattern.

- **Rule Purpose**: Verify that the visible text length of the element matches a pattern starting with 2 followed by digits  
- **Type**: Action  
- **Argument**: Check if element text length matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Match - Validates that the length matches the expected pattern  
    - **Expected**: ^2\d+$ - The length must start with 2 and be followed by one or more digits  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^2\\d+$}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
