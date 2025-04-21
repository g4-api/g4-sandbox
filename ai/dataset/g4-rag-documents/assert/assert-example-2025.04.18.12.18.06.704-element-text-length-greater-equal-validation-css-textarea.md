### Textarea Value Text Length GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element, identified by the CSS selector `textarea#content`, is greater than or equal to 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than or equal to 150.

- **Rule Purpose**: Verify that the text length of the textarea's value attribute is at least 150 characters  
- **Type**: Action  
- **Argument**: Check if the element's text length meets the specified condition  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text or attribute value  
    - **Operator**: GreaterEqual - The length must be greater than or equal to the expected value  
    - **Expected**: 150 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:150}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert"
}
```
