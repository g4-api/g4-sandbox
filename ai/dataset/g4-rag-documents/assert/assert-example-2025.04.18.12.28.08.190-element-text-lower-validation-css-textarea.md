### Element Text Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the CssSelector `textarea#content` is lower than the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric value in the textarea's value attribute is less than 42  
- **Type**: Action  
- **Argument**: Verify that extracted numeric text is lower than expected value 42  
  - **Parameters**:  
    - **Condition**: ElementText - Use the text content of an element or attribute  
    - **Operator**: Lower - Check if the actual value is less than the expected value  
    - **Expected**: 42 - The value to compare against  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Lower --Expected:42}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
