### Element Text Greater Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the Id `content` is greater than the expected value 42.  
The visible text content is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric value in the element with Id "content" is greater than 42  
- **Type**: Action  
- **Argument**: Verify that element text numeric value is greater than expected  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Greater - Compares if the actual value is greater than the expected  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Greater --Expected:42}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
