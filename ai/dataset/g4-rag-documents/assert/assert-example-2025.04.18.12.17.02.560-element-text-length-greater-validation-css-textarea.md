### Textarea Value Text Length Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element identified by the CSS selector `textarea#content` is greater than 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,110})` is applied to the `value` attribute to extract up to 110 characters into a capture group.  
The assertion passes only if more than 100 characters are captured; if exactly 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of a textarea's value attribute is greater than 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater than 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: Greater - Compares if the actual length is greater than the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,110})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:100}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,110})"
}
```
