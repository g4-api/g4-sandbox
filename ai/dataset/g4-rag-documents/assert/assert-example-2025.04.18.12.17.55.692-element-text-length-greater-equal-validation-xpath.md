### Element Text Length GreaterEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the Xpath selector `//div[@id='content']` is greater than or equal to 100 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is greater than or equal to 100; if fewer than 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the visible text length of a specified element is at least 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater or equal to 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: GreaterEqual - Verifies the length is greater than or equal to the expected value  
    - **Expected**: 100 - The minimum number of characters required  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:100}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
