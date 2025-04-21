### Page Title NotMatch Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the computed page title, after extracting up to 10 characters, does not match the expected pattern `^Lorem ipsu$`.  
A regular expression `(?s)^(.{0,10})` is applied to the page title to extract up to 10 characters into a capture group.  
A regular expression `^Lorem ipsu$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the extracted 10-character capture group does not match the pattern `^Lorem ipsu$`; otherwise, it fails.

- **Rule Purpose**: Check that the first 10 characters of the page title do not exactly match "Lorem ipsu".  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify page title does not match expected pattern  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title as the input for validation  
    - **Operator**: NotMatch - Checks that the value does not match the expected pattern  
    - **Expected**: ^Lorem ipsu$ - The pattern that the extracted title segment should not match  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:NotMatch --Expected:^Lorem ipsu$}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
