### Element Text Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the CssSelector `div#content` matches the expected pattern `^Lorem ipsu$`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the visible text to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted text to test for an exact match.  
The assertion passes only if the extracted text matches the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the specified element exactly matches the expected pattern.  
- **Type**: Action  
- **Argument**: Check if element text matches the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Match - Tests if the text matches a pattern  
    - **Expected**: ^Lorem ipsu$ - The exact text pattern to match  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Lorem ipsu$}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
