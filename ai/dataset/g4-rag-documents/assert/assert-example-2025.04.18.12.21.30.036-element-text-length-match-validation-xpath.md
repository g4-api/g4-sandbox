### Element Text Length Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the Xpath selector `//div[@id='content']` has a length that matches the regular expression pattern `^2\d+$`.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The regular expression is used to validate that the computed length (as a string) begins with the digit 2 and is followed by one or more digits.  
The assertion passes only if the computed length exactly matches this pattern.

- **Rule Purpose**: Verify that the visible text length of a specific element matches a pattern starting with 2 followed by digits  
- **Type**: Action  
- **Argument**: Check if element text length matches a pattern starting with 2 followed by digits  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: Match - Uses a regular expression to match the length string  
    - **Expected**: ^2\d+$ - The length must start with 2 and be followed by one or more digits  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^2\\d+$}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
