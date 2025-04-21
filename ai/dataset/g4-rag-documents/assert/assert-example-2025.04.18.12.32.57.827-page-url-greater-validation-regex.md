### Page URL Greater Validation With Extraction

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
This example demonstrates how the Assert plugin verifies that the numeric value extracted from the page URL is greater than the expected value 42.  
A regular expression `\d+` is applied to the page URL to extract the first numeric sequence into a capture group.  
The assertion passes only if the extracted number is greater than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the number extracted from the page URL is greater than 42  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the extracted page URL number is greater than 42  
  - **Parameters**:  
    - **Condition**: PageUrl - Use the page URL as the source for extraction  
    - **Operator**: Greater - Check if the extracted value is greater than the expected value  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Greater --Expected:42}}",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
