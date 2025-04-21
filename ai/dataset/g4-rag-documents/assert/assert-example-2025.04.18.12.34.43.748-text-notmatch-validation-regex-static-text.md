### Text NotMatch Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `123-45-6789` does not match the expected pattern `\d{3}-\d{2}-\d{4}`.  
The validation uses the full provided text string, including any whitespace or formatting.  
A regular expression `\d{3}-\d{2}-\d{4}` is applied to the provided text to test for a non-match.  
The assertion passes only if the provided text value does not match the pattern `\d{3}-\d{2}-\d{4}`; otherwise, it fails.

- **Rule Purpose**: Verify that the given text does not match the specified pattern.  
- **Type**: Action  
- **Argument**: Check that text does not match the pattern \d{3}-\d{2}-\d{4}  
  - **Parameters**:  
    - **Condition**: Text - Checks text content  
    - **Operator**: NotMatch - Validates that the text does not match the pattern  
    - **Expected**: \d{3}-\d{2}-\d{4} - The pattern to test against  
- **On Element**: 123-45-6789  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:NotMatch --Expected:\\d{3}-\\d{2}-\\d{4}}}",
  "onElement": "123-45-6789",
  "pluginName": "Assert"
}
```
