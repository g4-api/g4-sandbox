### Element Text LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the CssSelector `textarea#content` is lower than or equal to the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric value in the textarea's value attribute is less than or equal to 42  
- **Type**: Action  
- **Argument**: Verify numeric value is lower or equal to 42  
  - **Parameters**:  
    - **Condition**: ElementText - Use the element's text or attribute text for validation  
    - **Operator**: LowerEqual - Check if the extracted value is less than or equal to the expected value  
    - **Expected**: 42 - The maximum allowed numeric value  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
