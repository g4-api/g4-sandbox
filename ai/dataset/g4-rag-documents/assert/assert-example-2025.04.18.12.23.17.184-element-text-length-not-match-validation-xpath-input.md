### Input Value Text Length NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element identified by the Xpath selector `//input[@id='content']` does not match the expected pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the value attribute to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length, when converted to a string, does not match the pattern `^15\d+$`.

- **Rule Purpose**: Verify that the length of the input element's value text does not match a specific numeric pattern.  
- **Type**: Action  
- **Argument**: Check that the length of the element's text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: NotMatch - Passes if the text length does not match the pattern  
    - **Expected**: ^15\d+$ - The pattern the length should not match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^15\\d+$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
