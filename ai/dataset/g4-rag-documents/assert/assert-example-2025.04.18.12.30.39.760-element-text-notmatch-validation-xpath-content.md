### Element Text NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the Xpath locator `//div[@id='content']` does not match the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the visible text to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the extracted 10-character capture group does not match the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Check that the visible text of the specified element does not match the given pattern.  
- **Type**: Action  
- **Argument**: Verify that element text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotMatch - Ensures the text does not match the pattern  
    - **Expected**: ^Lorem ipsu$ - The pattern that the text should not match  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsu$}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
