### Input Value Text Length Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element, identified by the Xpath selector `//input[@id='content']`, matches the expected pattern `^1\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the `value` attribute to extract up to 100 characters into a capture group. The computed length, when converted to a string, must match the pattern `^1\d+$` (for example, '10', '11', '150', etc.).  
The assertion passes only if the computed length matches this pattern.

- **Rule Purpose**: Verify that the length of the input element's value attribute text matches a pattern starting with 1 followed by digits  
- **Type**: Action  
- **Argument**: Check if the length of the element's text matches the pattern ^1\d+$  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the text content  
    - **Operator**: Match - Compares the length string against a pattern  
    - **Expected**: ^1\d+$ - The pattern the length must match (starts with 1 followed by digits)  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^1\\d+$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
