### Page Title Greater Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page title is greater than the expected value 42.  
A regular expression `\d+` is applied to the page title to extract the first numeric sequence into a capture group.  
The assertion passes only if that extracted number is greater than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the number extracted from the page title is greater than 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if page title number is greater than expected value  
  - **Parameters**:  
    - **Condition**: PageTitle - Use the page title as the source for validation  
    - **Operator**: Greater - Check if the extracted value is greater than the expected value  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Greater --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
