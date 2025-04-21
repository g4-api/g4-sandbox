### Element Text Length LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the CSS selector `#content` is less than or equal to 255 characters.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than or equal to 255.

- **Rule Purpose**: Verify that the visible text length of the element #content is at most 255 characters  
- **Type**: Action  
- **Argument**: Check if element text length is less than or equal to 255  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text content of an element  
    - **Operator**: LowerEqual - Verifies the length is less than or equal to the expected value  
    - **Expected**: 255 - The maximum allowed length of the element's visible text  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:255}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
