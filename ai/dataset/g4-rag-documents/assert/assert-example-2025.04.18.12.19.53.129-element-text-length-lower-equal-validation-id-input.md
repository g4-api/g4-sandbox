### Input Value Text Length LowerEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) with the Id `content` is less than or equal to 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than or equal to 150.

- **Rule Purpose**: Verify that the text length of the value attribute on the input element with Id "content" is at most 150 characters  
- **Type**: Action  
- **Argument**: Check if the element's text length is less than or equal to 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text content or attribute value  
    - **Operator**: LowerEqual - Verifies the length is less than or equal to the expected value  
    - **Expected**: 150 - The maximum allowed length  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
