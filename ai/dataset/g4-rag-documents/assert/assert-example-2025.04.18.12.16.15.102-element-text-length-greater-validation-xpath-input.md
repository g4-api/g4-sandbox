### Input Value Text Length Greater Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the Xpath selector `//input[@id='content']` is greater than 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,110})` is applied to the `value` attribute to extract up to 110 characters into a capture group.  
The assertion passes only if more than 100 characters are captured; if exactly 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of the input element's value attribute is greater than 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater than 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text in an element or attribute  
    - **Operator**: Greater - Verifies the length is greater than the expected value  
    - **Expected**: 100 - The minimum number of characters required  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,110})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:100}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,110})"
}
```
