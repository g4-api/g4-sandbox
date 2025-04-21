### Element Text NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the Xpath locator `//textarea[@id='content']` does not match the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the `value` attribute to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the text from the `value` attribute does not match the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the value attribute of a specific textarea does not match a given pattern.  
- **Type**: Action  
- **Argument**: Check that the element text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: NotMatch - Validates that the text does not match the expected pattern  
    - **Expected**: ^Lorem ipsu$ - The pattern that the text should not match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsu$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
