### Element Text GreaterEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the XPath locator `//div[@id='content']` is greater than or equal to the expected value 42.  
The visible text content is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the specified element is at least 42  
- **Type**: Action  
- **Argument**: Verify element text number is greater or equal to 42  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: GreaterEqual - Compares if the value is greater than or equal to the expected  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:GreaterEqual --Expected:42}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
