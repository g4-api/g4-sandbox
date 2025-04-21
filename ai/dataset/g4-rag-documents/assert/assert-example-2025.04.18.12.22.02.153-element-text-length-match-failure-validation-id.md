### Element Text Length Match Validation (Failure Expected) Using Id

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element with the Id `content` matches the pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the `value` attribute to extract up to 100 characters into a capture group.  
Given that the extraction is capped at 100 characters, the computed length will never fulfill the pattern, causing the assertion to fail.

- **Rule Purpose**: Verify that the length of the text in the value attribute of the element with Id "content" matches a specific numeric pattern.  
- **Type**: Action  
- **Argument**: Check if the length of the element text matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: Match - Tests if the length matches the expected pattern  
    - **Expected**: ^15\d+$ - The length should start with "15" followed by one or more digits  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^15\\d+$}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
