### Element Text Length NotEqual with Regex Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the Xpath selector `//div[@id='content']` is not exactly 100 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if fewer than 100 characters are captured or if no match occurs; it fails if exactly 100 characters are captured.

- **Rule Purpose**: Verify that the visible text length of the specified element is not exactly 100 characters using a regex extraction  
- **Type**: Action  
- **Argument**: Check if the element text length is not equal to 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: NotEqual - The length must not be equal to the expected value  
    - **Expected**: 100 - The length value to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotEqual --Expected:100}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
