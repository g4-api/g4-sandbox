### Element Text LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the XPath locator `//div[@id='content']` is lower than or equal to the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the specified element is less than or equal to 42  
- **Type**: Action  
- **Argument**: Verify element text is lower or equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate text content of an element  
    - **Operator**: LowerEqual - Check if the value is less than or equal to the expected  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
