### Input Value Text Length LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the Xpath selector `//input[@id='content']` is less than or equal to 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than or equal to 150.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is at most 150 characters  
- **Type**: Action  
- **Argument**: Check if element text length is lower or equal to 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text in an element or attribute  
    - **Operator**: LowerEqual - Verifies the length is less than or equal to the expected value  
    - **Expected**: 150 - The maximum allowed length  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //input[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:150}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//input[@id='content']",
  "pluginName": "Assert"
}
```
