### Element Text Length Equal with Regex Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text length of the element identified by the Xpath selector `//div[@id='content']` is exactly 100 characters.  
The computed text length excludes HTML tags and counts only the visible text as provided by the WebDriver Get Element Text endpoint.  
A regular expression `(?s)^(.{0,100})` is applied to extract up to 100 characters from the visible text.  
The assertion evaluates to `true` only if the extracted string is exactly 100 characters long. If the element contains fewer than 100 visible characters, the regex match group will capture fewer than 100 characters, causing the assertion to fail.

- **Rule Purpose**: Verify that the visible text length of the specified element is exactly 100 characters using a regex extraction.  
- **Type**: Action  
- **Argument**: Check if the element's visible text length equals 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Equal - Compares the text length for equality  
    - **Expected**: 100 - The expected length of the visible text  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:100}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
