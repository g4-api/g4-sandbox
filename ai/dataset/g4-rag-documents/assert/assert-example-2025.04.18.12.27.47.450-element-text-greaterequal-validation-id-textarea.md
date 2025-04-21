### Element Text GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the Id `content` is greater than or equal to the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Verify that the numeric text from a specific element attribute is at least 42  
- **Type**: Action  
- **Argument**: Check if element text meets numeric condition  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: GreaterEqual - Validates that the value is greater than or equal to the expected number  
    - **Expected**: 42 - The numeric threshold for validation  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:GreaterEqual --Expected:42}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
