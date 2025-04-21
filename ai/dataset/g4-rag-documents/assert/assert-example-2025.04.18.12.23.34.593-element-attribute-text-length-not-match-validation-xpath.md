### Element Text Length NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of a textarea element with the XPath locator `//textarea[@id='content']` does not match the expected pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the value attribute to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length, when converted to a string, does not match the pattern `^15\d+$`.

- **Rule Purpose**: Verify that the length of the textarea's value attribute text does not match the pattern starting with "15" followed by digits.  
- **Type**: Action  
- **Argument**: Check that the length of the element text does not match a specific pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Uses the length of the element's text for the assertion  
    - **Operator**: NotMatch - Passes if the text length does not match the expected pattern  
    - **Expected**: ^15\d+$ - The pattern that the text length should not match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^15\\d+$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert"
}
```
