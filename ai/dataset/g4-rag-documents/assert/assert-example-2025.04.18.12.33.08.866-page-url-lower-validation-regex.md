### Page URL Lower Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page URL is lower than the expected value 42.  
A regular expression `\d+` is applied to the page URL to extract the first numeric sequence into a capture group.  
The assertion passes only if the extracted number is lower than 42; otherwise, it fails.

- **Rule Purpose**: Check that the number extracted from the page URL is less than 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Compare extracted page URL number to expected value  
  - **Parameters**:  
    - **Condition**: PageUrl - Use the page URL for validation  
    - **Operator**: Lower - Check if the extracted value is lower than expected  
    - **Expected**: 42 - The threshold value for comparison  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Lower --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
