### Textarea Value Text Length GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element identified by the CSS selector `textarea#content` is greater than or equal to 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,})` is applied to the `value` attribute to extract the full visible text into a capture group.  
The assertion passes only if the computed length is greater than or equal to 100 characters; it fails if fewer than 100 characters are captured.

- **Rule Purpose**: Verify that the length of the textarea's value attribute text is at least 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater or equal to 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: GreaterEqual - Verifies the length is greater than or equal to the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:100}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,})"
}
```
