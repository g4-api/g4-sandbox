### Element Text LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the XPath locator `//textarea[@id='content']` is lower than or equal to the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the value attribute of a specific textarea is less than or equal to 42  
- **Type**: Action  
- **Argument**: Validate element text against a numeric condition  
  - **Parameters**:  
    - **Condition**: ElementText - Use the element's text or attribute text for validation  
    - **Operator**: LowerEqual - Check if the extracted value is less than or equal to the expected value  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
