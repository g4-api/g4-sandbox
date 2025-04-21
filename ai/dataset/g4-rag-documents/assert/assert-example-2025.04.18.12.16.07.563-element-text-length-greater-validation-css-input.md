### Input Value Text Length Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the CSS selector `input#content` is greater than 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,110})` is applied to the `value` attribute to extract up to 110 characters into a capture group.  
The assertion passes only if more than 100 characters are captured; if exactly 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is greater than 100 characters  
- **Type**: Action  
- **Argument**: Check if the length of the element's text is greater than 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute  
    - **Operator**: Greater - The length must be greater than the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: input#content  
- **Regular Expression**: (?s)^(.{0,110})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:100}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "input#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,110})"
}
```
