### Page URL Match Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected pattern.  
This example demonstrates how the Assert plugin verifies that the current page URL, after extracting up to 10 characters, matches the expected pattern `^https://ex$`.  
A regular expression `(?s)^(.{0,10})` is applied to the page URL to extract up to 10 characters into a capture group.  
A regular expression `^https://ex$` is then applied to the extracted 10-character capture group to test for an exact match.  
The assertion passes only if the extracted 10-character capture group matches the pattern `^https://ex$`; otherwise, it fails.

- **Rule Purpose**: Check that the first 10 characters of the page URL exactly match the pattern ^https://ex$.  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify that the page URL matches a specific pattern after extraction  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: Match - Tests if the value matches the expected pattern  
    - **Expected**: ^https://ex$ - The exact pattern to match  
- **Regular Expression**: (?s)^(.{0,10}) - Extracts up to 10 characters from the page URL  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Match --Expected:^https://ex$}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
