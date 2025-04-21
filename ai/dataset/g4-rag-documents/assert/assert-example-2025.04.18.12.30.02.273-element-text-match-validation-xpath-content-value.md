### Element Text Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the Xpath locator `//textarea[@id='content']` matches the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the `value` attribute to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for an exact match.  
The assertion passes only if the text from the `value` attribute matches the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the value attribute of a specific textarea exactly matches the pattern ^Lorem ipsu$.  
- **Type**: Action  
- **Argument**: Check if element text matches the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: Match - Tests if the text matches the expected pattern exactly  
    - **Expected**: ^Lorem ipsu$ - The exact text pattern to match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Lorem ipsu$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
