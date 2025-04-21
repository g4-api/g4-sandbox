### Input Value Text Length Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element (of type text) identified by the CSS selector `input#content` matches the pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The expected outcome is that the computed length, when converted to a string, will begin with '15' (for example, '150', '151', etc.).  
The assertion passes only if the computed length meets this pattern.

- **Rule Purpose**: Verify that the length of the input element's value text matches a pattern starting with "15" followed by digits  
- **Type**: Action  
- **Argument**: Check if the length of the element's text matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: Match - Uses pattern matching to compare values  
    - **Expected**: ^15\d+$ - The length string should start with "15" followed by one or more digits  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: input#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^15\\d+$}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "input#content",
  "pluginName": "Assert"
}
```
