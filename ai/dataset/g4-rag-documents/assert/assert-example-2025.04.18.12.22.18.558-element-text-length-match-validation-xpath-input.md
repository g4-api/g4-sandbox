### Input Value Text Length Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element (of type text) identified by the Xpath selector `//input[@id='content']` matches the pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The expected outcome is that the computed length, when converted to a string, will start with '15' (for example, '150', '151', etc.).  
The assertion passes only if the computed length meets this pattern.

- **Rule Purpose**: Verify that the length of the input element's value text matches a pattern starting with "15" followed by digits  
- **Type**: Action  
- **Argument**: Check if the element text length matches the pattern ^15\d+$  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: Match - Uses a regular expression match for validation  
    - **Expected**: ^15\d+$ - The expected pattern that the length string should match  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^15\\d+$}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert"
}
```
