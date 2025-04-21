### Element Text NotMatch Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the CssSelector `textarea#content` does not match the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the `value` attribute to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the text from the `value` attribute does not match the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the value attribute of the textarea does not match the pattern ^Lorem ipsu$.  
- **Type**: Action  
- **Argument**: Check that the element text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Use the element's text content for validation  
    - **Operator**: NotMatch - Assert that the text does not match the pattern  
    - **Expected**: ^Lorem ipsu$ - The pattern that the text should not match  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsu$}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
