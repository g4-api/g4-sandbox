### Element Text Length Equal Validation Using Id

This example demonstrates how the Assert plugin verifies that the text length of the element with the Id `content` is exactly 255 characters.  
The computed text length excludes HTML tags and counts only the visible text as returned by the WebDriver Get Element Text endpoint. For nested HTML, the length is determined by concatenating the visible text from all child elements.  
If the text length equals 255, the assert evaluates to `true`.

- **Rule Purpose**: Check if the visible text length of a specified element equals 255 characters  
- **Type**: Action  
- **Argument**: Verify that element text length matches expected value  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: Equal - Compares if the text length is exactly the expected value  
    - **Expected**: 255 - The exact length expected for the element's visible text  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:255}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
