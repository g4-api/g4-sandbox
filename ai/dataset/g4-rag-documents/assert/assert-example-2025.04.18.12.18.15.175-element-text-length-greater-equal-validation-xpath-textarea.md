### Textarea Value Text Length GreaterEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element, identified by the Xpath selector `//textarea[@id='content']`, is greater than or equal to 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than or equal to 150.

- **Rule Purpose**: Check that the text length of a textarea's value attribute is at least 150 characters  
- **Type**: Action  
- **Argument**: Verify that the element's text length meets or exceeds a threshold  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: GreaterEqual - Validates that the length is greater than or equal to the expected value  
    - **Expected**: 150 - The minimum length required for the assertion to pass  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: null  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:150}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert",
  "regularExpression": null
}
```
