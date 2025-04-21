### Element Text Lower Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the Id `content` is lower than the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text extracted from the element with Id "content" is less than 42  
- **Type**: Action  
- **Argument**: Verify that extracted numeric text is lower than 42  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate text content of an element  
    - **Operator**: Lower - Check if the value is less than the expected  
    - **Expected**: 42 - The threshold value for comparison  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Lower --Expected:42}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
