### Element Text LowerEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the Id `content` is lower than or equal to the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text from a specific attribute is less than or equal to 42  
- **Type**: Action  
- **Argument**: Validate that extracted numeric value is lower or equal to 42  
  - **Parameters**:  
    - **Condition**: ElementText - Use text from an element or attribute  
    - **Operator**: LowerEqual - Check if value is less than or equal to expected  
    - **Expected**: 42 - The maximum allowed numeric value  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
