### Page Title Lower Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page title is lower than the expected value 42.  
A regular expression `\d+` is applied to the page title to extract the first numeric sequence into a capture group.  
The assertion passes only if that extracted number is lower than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the number extracted from the page title is less than 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the page title number is lower than 42  
  - **Parameters**:  
    - **Condition**: PageTitle - Use the page title as the source for validation  
    - **Operator**: Lower - Check if the extracted value is less than the expected value  
    - **Expected**: 42 - The threshold number to compare against  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Lower --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
