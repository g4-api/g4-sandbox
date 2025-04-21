### Textarea Value Text Length GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea, with the Id `content`, is greater than or equal to 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than or equal to 150.

- **Rule Purpose**: Verify that the length of the textarea's value attribute text is at least 150 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater or equal to 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: GreaterEqual - Verifies the length is greater than or equal to the expected value  
    - **Expected**: 150 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
