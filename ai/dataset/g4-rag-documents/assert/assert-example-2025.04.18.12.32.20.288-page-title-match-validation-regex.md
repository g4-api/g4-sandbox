### Page Title Match Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the computed page title, after extracting up to 10 characters, matches the expected pattern `^Lorem ipsu$`.  
A regular expression `(?s)^(.{0,10})` is applied to the page title to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for an exact match.  
The assertion passes only if the extracted 10-character capture group matches the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Check that the first 10 characters of the page title exactly match "Lorem ipsu".  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify page title matches expected pattern  
  - **Parameters**:  
    - **Condition**: PageTitle - Use the page title as the value to check  
    - **Operator**: Match - Check if the value matches the expected pattern  
    - **Expected**: ^Lorem ipsu$ - The exact pattern the extracted title must match  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Match --Expected:^Lorem ipsu$}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
