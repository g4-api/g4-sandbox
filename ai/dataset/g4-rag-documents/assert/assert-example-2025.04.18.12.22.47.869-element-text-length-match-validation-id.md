### Element Text Length Match Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element with the Id `content` matches the expected pattern `^1\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the `value` attribute to extract up to 100 characters into a capture group. The computed length, when converted to a string, must match the pattern `^1\d+$` (for example, '10', '11', '150', etc.).  
The assertion passes only if the computed length matches this pattern.

- **Rule Purpose**: Verify that the length of the text in the value attribute of the element with Id 'content' matches a pattern starting with '1' followed by digits  
- **Type**: Action  
- **Argument**: Check if the length of the element's value attribute text matches the pattern ^1\d+$  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text  
    - **Operator**: Match - Compares the computed length against a pattern  
    - **Expected**: ^1\d+$ - The length must start with '1' followed by one or more digits  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^1\\d+$}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
