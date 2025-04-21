### Page URL NotEqual Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
This example demonstrates how the Assert plugin verifies that the current page URL, after extracting up to 10 characters, does not match the expected value `https://ex`.  
A regular expression `(?s)^(.{0,10})` is applied to the page URL to extract up to 10 characters into a capture group.  
The assertion passes only if the extracted 10-character capture group does not match `https://ex`; otherwise, it fails.

- **Rule Purpose**: Verify that the first 10 characters of the page URL are not equal to a specified value.  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the page URL does not equal the expected value after extraction  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: NotEqual - Verifies the URL is not equal to the expected value  
    - **Expected**: https://ex - The URL value to compare against  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:NotEqual --Expected:https://ex}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
