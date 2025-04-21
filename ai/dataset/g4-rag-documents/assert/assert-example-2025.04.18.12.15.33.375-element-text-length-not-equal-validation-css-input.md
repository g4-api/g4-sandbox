### Input Value Text Length NotEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the CSS selector `input#content` is not exactly 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,110})` is applied to the `value` attribute to extract up to 110 characters into a capture group.  
The assertion passes only if the length of the regex capture group is not exactly 100; if exactly 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is not exactly 100 characters  
- **Type**: Action  
- **Argument**: Check if the length of the element text is not equal to 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: NotEqual - The length must not be equal to the expected value  
    - **Expected**: 100 - The length value to compare against  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: input#content  
- **Regular Expression**: (?s)^(.{0,110})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotEqual --Expected:100}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "input#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,110})"
}
```
