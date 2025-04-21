### Input Value Text Length Equal Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) with the Id `content` is exactly 150 characters.  
The text length is computed solely from the value attribute, excluding any HTML markup.  
If the value attribute contains exactly 150 characters (regardless of visual presentation), the assert evaluates to `true`.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is exactly 150 characters  
- **Type**: Action  
- **Argument**: Check if the text length of the value attribute equals 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: Equal - Compares if the length is exactly the expected value  
    - **Expected**: 150 - The exact length expected for the text  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
