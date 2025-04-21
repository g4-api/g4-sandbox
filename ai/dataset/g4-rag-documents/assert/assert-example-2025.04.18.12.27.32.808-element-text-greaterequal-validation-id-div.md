### Element Text GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the Id `content` is greater than or equal to the expected value 42.  
The visible text content is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Verify that the numeric text in the element with Id "content" is at least 42  
- **Type**: Action  
- **Argument**: Check if element text numeric value meets or exceeds 42  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: GreaterEqual - Verifies the value is greater than or equal to the expected  
    - **Expected**: 42 - The minimum numeric value expected  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:GreaterEqual --Expected:42}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
