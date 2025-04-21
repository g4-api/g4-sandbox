### Element Text LowerEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the Id `content` is lower than or equal to the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the element with Id "content" is less than or equal to 42  
- **Type**: Action  
- **Argument**: Verify that element text is lower or equal to expected value 42  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: LowerEqual - Compares if the actual value is less than or equal to the expected  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
