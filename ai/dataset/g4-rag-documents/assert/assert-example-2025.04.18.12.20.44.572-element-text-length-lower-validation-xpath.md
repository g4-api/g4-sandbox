### Element Text Length Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the Xpath selector `//div[@id='content']` is less than 100 characters.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is less than 100; if 100 or more characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the visible text length of a specific element is less than 100 characters  
- **Type**: Action  
- **Argument**: Check if the element's visible text length is lower than 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Lower - Verifies the length is less than the expected value  
    - **Expected**: 100 - The maximum allowed length of the visible text  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:100}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
