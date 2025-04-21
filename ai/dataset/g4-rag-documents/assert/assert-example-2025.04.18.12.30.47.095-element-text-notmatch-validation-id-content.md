### Element Text NotMatch Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the Id `content` does not match the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the visible text to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the extracted 10-character capture group does not match the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text from the element with Id "content" does not exactly match the pattern "^Lorem ipsu$" within the first 10 characters  
- **Type**: Action  
- **Argument**: Check that element text does not match a specific pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotMatch - Ensures the text does not match the expected pattern  
    - **Expected**: ^Lorem ipsu$ - The pattern that the text should not match  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsu$}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
