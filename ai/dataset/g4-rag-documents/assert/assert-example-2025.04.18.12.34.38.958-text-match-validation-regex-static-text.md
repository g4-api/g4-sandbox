### Text Match Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `123-45-6789` matches the expected pattern `\d{3}-\d{2}-\d{4}`.  
The validation uses the full provided text string, including any whitespace or formatting.  
A regular expression `\d{3}-\d{2}-\d{4}` is applied to the provided text to test for a match.  
The assertion passes only if the provided text value matches the pattern `\d{3}-\d{2}-\d{4}`; otherwise, it fails.

- **Rule Purpose**: Verify that the given text exactly matches the specified pattern for a social security number format.  
- **Type**: Action  
- **Argument**: Check if text matches the pattern \d{3}-\d{2}-\d{4}  
  - **Parameters**:  
    - **Condition**: Text - Checks the text content  
    - **Operator**: Match - Tests if the text matches the pattern  
    - **Expected**: \d{3}-\d{2}-\d{4} - The regular expression pattern to match  
- **On Element**: 123-45-6789  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Match --Expected:\\d{3}-\\d{2}-\\d{4}}}",
  "onElement": "123-45-6789",
  "pluginName": "Assert"
}
```
