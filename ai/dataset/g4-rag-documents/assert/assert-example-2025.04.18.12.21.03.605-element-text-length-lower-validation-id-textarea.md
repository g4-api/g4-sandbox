### Textarea Value Text Length Lower Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of a textarea with the Id `content` is less than 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than 150; if 150 or more characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the text length of the value attribute in the textarea with Id "content" is less than 150 characters  
- **Type**: Action  
- **Argument**: Check if the text length is lower than 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of text content or attribute value  
    - **Operator**: Lower - Verifies the length is less than the expected value  
    - **Expected**: 150 - The maximum allowed length for the text  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
