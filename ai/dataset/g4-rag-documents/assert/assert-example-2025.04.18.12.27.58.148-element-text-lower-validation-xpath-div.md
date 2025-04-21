### Element Text Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the XPath locator `//div[@id='content']` is lower than the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than 42; otherwise, it fails.

- **Rule Purpose**: Verify that the numeric text in the specified element is less than 42  
- **Type**: Action  
- **Argument**: Check if element text number is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate text from an element  
    - **Operator**: Lower - Check if the extracted value is less than the expected  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Lower --Expected:42}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
