### Element Text Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the text of the `value` attribute of the textarea element identified by the XPath locator `//textarea[@id='content']` is lower than the expected value 42.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `\d+` is applied to the attribute text to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the numeric value in the textarea's value attribute is less than 42  
- **Type**: Action  
- **Argument**: Check if element text is lower than expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: Lower - Validates that the actual value is less than the expected value  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Lower --Expected:42}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
