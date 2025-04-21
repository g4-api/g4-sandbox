### Page Title Greater Equal Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page title is greater than or equal to the expected value 42.  
A regular expression `\d+` is applied to the page title to extract the first numeric sequence into a capture group.  
The assertion passes only if that extracted number is greater than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Verify that the number extracted from the page title is at least 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if page title number is greater or equal to 42  
  - **Parameters**:  
    - **Condition**: PageTitle - Use the page title as the source for validation  
    - **Operator**: GreaterEqual - Check if the extracted number is greater than or equal to the expected value  
    - **Expected**: 42 - The minimum numeric value required for the assertion to pass  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:GreaterEqual --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
