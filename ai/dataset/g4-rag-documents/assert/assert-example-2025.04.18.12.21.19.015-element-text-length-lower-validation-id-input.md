### Input Value Text Length Lower Validation Using Id

This example demonstrates how the Assert plugin verifies that the text from the `value` attribute of an input element with the Id `content` is less than 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the `value` attribute to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is less than 100; if 100 or more characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of the input element's value attribute is less than 100 characters  
- **Type**: Action  
- **Argument**: Check if the element text length is lower than 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text content or attribute value  
    - **Operator**: Lower - Verifies the length is less than the expected value  
    - **Expected**: 100 - The maximum allowed length  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:100}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
