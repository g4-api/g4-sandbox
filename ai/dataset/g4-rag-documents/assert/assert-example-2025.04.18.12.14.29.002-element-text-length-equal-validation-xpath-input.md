### Input Value Text Length Equal Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the Xpath selector `//input[@id='content']` is exactly 100 characters.  
The text length is computed solely from the attribute value, excluding any HTML markup.  
A regular expression `(?s)^(.{0,100})` is used to extract up to 100 characters, and the assertion passes only if exactly 100 characters are captured.  
If the extracted match is shorter than 100 characters, the assertion fails.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is exactly 100 characters  
- **Type**: Action  
- **Argument**: Check if the element's text length equals 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text or attribute value  
    - **Operator**: Equal - Compares the length for equality  
    - **Expected**: 100 - The expected length to match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:100}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
