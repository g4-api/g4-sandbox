### Element Text Length GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the visible text content of the element with the Id `content` is greater than or equal to 100 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is greater than or equal to 100; if fewer than 100 characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the visible text length of the element with Id "content" is at least 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater or equal to 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: GreaterEqual - Validates that the length is greater than or equal to the expected value  
    - **Expected**: 100 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:100}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
