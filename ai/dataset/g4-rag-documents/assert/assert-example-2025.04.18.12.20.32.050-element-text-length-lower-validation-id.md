### Element Text Length Lower Validation Using Id

This example demonstrates how the Assert plugin verifies that the visible text of the element with the Id `content` is less than 255 characters.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than 255; if it is greater than or equal to 255, the assertion fails.

- **Rule Purpose**: Check that the visible text length of the element with Id "content" is less than 255 characters  
- **Type**: Action  
- **Argument**: Verify that element text length is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Lower - Compares if the text length is less than the expected value  
    - **Expected**: 255 - The maximum allowed length for the element's visible text  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:255}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
