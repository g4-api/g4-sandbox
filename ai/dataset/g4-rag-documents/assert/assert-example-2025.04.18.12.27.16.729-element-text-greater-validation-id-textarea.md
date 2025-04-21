### Element Text Greater Validation Using Id

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the Id `content` is greater than the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the text content to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the numeric value from the specified element's attribute text is greater than 42  
- **Type**: Action  
- **Argument**: Check if element text value is greater than 42  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: Greater - Compares if the actual value is greater than the expected  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Greater --Expected:42}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
