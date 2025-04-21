### Textarea Value Text Length Greater Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea with the Id `content` is greater than 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,200})` is applied to the `value` attribute to extract up to 200 characters into a capture group.  
The assertion passes only if the computed length is greater than 150; if exactly 150 characters are captured or fewer, the assertion fails.

- **Rule Purpose**: Verify that the text length of the textarea's value attribute is greater than 150 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater than 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text in an element or attribute  
    - **Operator**: Greater - Tests if the length is greater than the expected value  
    - **Expected**: 150 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,200})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,200})"
}
```
