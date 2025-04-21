### Page URL NotMatch Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected pattern.  
This example demonstrates how the Assert plugin verifies that the current page URL, after extracting up to 10 characters, does not match the expected pattern `^https://ex$`.  
A regular expression `(?s)^(.{0,10})` is applied to the page URL to extract up to 10 characters into a capture group.  
A regular expression `^https://ex$` is then applied to the extracted 10-character capture group to test for a non-match.  
The assertion passes only if the extracted 10-character capture group does not match the pattern `^https://ex$`; otherwise, it fails.

- **Rule Purpose**: Verify that the first 10 characters of the page URL do not match the pattern `^https://ex$`.  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check that the page URL does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: PageUrl - Use the page URL for validation  
    - **Operator**: NotMatch - Assert that the value does not match the pattern  
    - **Expected**: ^https://ex$ - The pattern to test against the extracted URL part  
- **Regular Expression**: (?s)^(.{0,10})  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:NotMatch --Expected:^https://ex$}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
