### Textarea Value Text Length GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea with the Id `content` is greater than or equal to 100 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,})` is applied to the `value` attribute to extract the full visible text into a capture group.  
The assertion passes only if the computed length is greater than or equal to 100 characters; it fails if fewer than 100 characters are captured.

- **Rule Purpose**: Verify that the text length of the value attribute on a textarea with Id "content" is at least 100 characters  
- **Type**: Action  
- **Argument**: Check if the length of the element's text is greater or equal to 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text content on an element or attribute  
    - **Operator**: GreaterEqual - Verifies the length is greater than or equal to the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Regular Expression**: (?s)^(.{0,})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:100}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,})"
}
```
