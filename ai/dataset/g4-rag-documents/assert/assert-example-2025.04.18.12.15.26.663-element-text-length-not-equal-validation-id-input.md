### Input Value Text Length NotEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) with the Id `content` does not equal 150 characters.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes only if the computed length is not exactly 150 characters.

- **Rule Purpose**: Verify that the length of the input element's value attribute text is not exactly 150 characters  
- **Type**: Action  
- **Argument**: Check that the text length of the value attribute is not equal to 150  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content or attribute value  
    - **Operator**: NotEqual - The length must not be equal to the expected value  
    - **Expected**: 150 - The length value to compare against  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotEqual --Expected:150}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
