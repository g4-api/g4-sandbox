### Textarea Value Text Length Greater Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea with the Id `content` is greater than 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,110})` is applied to the `value` attribute to extract up to 110 characters into a capture group.  
The assertion passes only if more than 100 characters are captured; if exactly 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of the value attribute in a textarea with a specific Id is greater than 100 characters  
- **Type**: Action  
- **Argument**: Check if the length of element text is greater than 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: Greater - Verifies the length is greater than the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Regular Expression**: (?s)^(.{0,110})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:100}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,110})"
}
```
