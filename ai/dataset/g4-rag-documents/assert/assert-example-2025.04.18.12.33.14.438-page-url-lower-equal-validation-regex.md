### Page URL LowerEqual Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page URL is lower than or equal to the expected value 42.  
A regular expression `\d+` is applied to the page URL to extract the first numeric sequence into a capture group.  
The assertion passes only if the extracted number is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the number extracted from the page URL is less than or equal to 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Validate page URL number with lower or equal comparison  
  - **Parameters**:  
    - **Condition**: PageUrl - Use the page URL as the source for validation  
    - **Operator**: LowerEqual - Check if the extracted value is less than or equal to the expected value  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:LowerEqual --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
