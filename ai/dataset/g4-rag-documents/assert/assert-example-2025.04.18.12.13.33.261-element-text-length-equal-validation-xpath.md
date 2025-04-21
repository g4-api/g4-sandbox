### Element Text Length Equal Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the element identified by the Xpath selector `//div[@id='content']` is exactly 255 characters.  
The computed text length excludes HTML tags and counts only the visible text as returned by the WebDriver Get Element Text endpoint. For nested HTML, the length is determined by concatenating the visible text from all child elements.  
If the text length equals 255, the assert evaluates to `true`.

- **Rule Purpose**: Check that the visible text length of a specific element equals 255 characters  
- **Type**: Action  
- **Argument**: Verify element text length equals 255  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: Equal - Compares the text length for equality  
    - **Expected**: 255 - The exact text length expected  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:255}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
