### Page URL Equal Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
This example demonstrates how the Assert plugin verifies that the current page URL, after extracting up to 10 characters, matches the expected value `https://ex`.  
A regular expression `(?s)^(.{0,10})` is applied to the page URL to extract up to 10 characters into a capture group.  
The assertion passes only if that extracted 10-character capture group exactly matches `https://ex`; otherwise, it fails.

- **Rule Purpose**: Check that the first 10 characters of the page URL exactly match "https://ex"  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify the page URL matches the expected value  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: Equal - Compares for exact equality  
    - **Expected**: https://ex - The expected URL substring to match  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Equal --Expected:https://ex}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
