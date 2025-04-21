### Textarea Value Text Length Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element identified by the Xpath selector `//textarea[@id='content']` is less than 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than 150; if 150 or more characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of the textarea's value attribute is less than 150 characters  
- **Type**: Action  
- **Argument**: Check if the element's text length is lower than 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text in an element or attribute  
    - **Operator**: Lower - Verifies the length is less than the expected value  
    - **Expected**: 150 - The maximum allowed length for the text  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:150}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert"
}
```
