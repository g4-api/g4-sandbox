### Page Title Lower Equal Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page title is lower than or equal to the expected value 42.  
A regular expression `\d+` is applied to the page title to extract the first numeric sequence into a capture group.  
The assertion passes only if that extracted number is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Verify that the number extracted from the page title is less than or equal to 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if page title number is lower or equal to 42  
  - **Parameters**:  
    - **Condition**: PageTitle - Use the page title as the source for validation  
    - **Operator**: LowerEqual - Check if the extracted number is less than or equal to the expected value  
    - **Expected**: 42 - The maximum allowed numeric value in the page title  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:LowerEqual --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
