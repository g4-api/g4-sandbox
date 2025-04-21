### Textarea Value Text Length Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea with the CSS selector `textarea#content` is greater than 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,200})` is applied to the `value` attribute to extract up to 200 characters into a capture group.  
The assertion passes only if the computed length is greater than 150; if exactly 150 characters are captured or fewer, the assertion fails.

- **Rule Purpose**: Verify that the text length of the textarea's value attribute is greater than 150 characters  
- **Type**: Action  
- **Argument**: Check if the element text length is greater than 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: Greater - Verifies the length is greater than the expected value  
    - **Expected**: 150 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,200})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:150}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,200})"
}
```
