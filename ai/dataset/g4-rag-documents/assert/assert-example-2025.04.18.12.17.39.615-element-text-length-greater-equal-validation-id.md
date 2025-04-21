### Element Text Length GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the visible text content of the element with the Id `content` is greater than or equal to 255 characters.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than or equal to 255.

- **Rule Purpose**: Verify that the visible text length of the element with Id "content" is at least 255 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater or equal to 255  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: GreaterEqual - Verifies the length is greater than or equal to the expected value  
    - **Expected**: 255 - The minimum length required for the assertion to pass  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:255}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
