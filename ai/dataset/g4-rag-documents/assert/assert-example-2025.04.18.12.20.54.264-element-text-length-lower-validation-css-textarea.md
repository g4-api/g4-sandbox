### Textarea Value Text Length Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea element identified by the CSS selector `textarea#content` is less than 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than 150; if 150 or more characters are captured, the assertion fails.

- **Rule Purpose**: Check that the text length of the textarea's value attribute is less than 150 characters  
- **Type**: Action  
- **Argument**: Verify text length is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text or attribute value  
    - **Operator**: Lower - Asserts the length is less than the expected value  
    - **Expected**: 150 - The maximum allowed length for the text  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:150}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert"
}
```
