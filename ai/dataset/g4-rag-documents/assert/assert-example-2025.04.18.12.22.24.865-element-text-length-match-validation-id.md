### Element Text Length Match Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element with the Id `content` matches the pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The expected outcome is that the computed length, when converted to a string, will start with '15' (for example, '150', '151', etc.).  
The assertion passes only if the computed length meets this pattern.

- **Rule Purpose**: Verify that the length of the text in the value attribute of the element with Id 'content' matches a specific numeric pattern  
- **Type**: Action  
- **Argument**: Check if element text length matches pattern ^15\d+$  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: Match - Compares the length using a regex match  
    - **Expected**: ^15\d+$ - The expected pattern for the length as a string  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^15\\d+$}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
