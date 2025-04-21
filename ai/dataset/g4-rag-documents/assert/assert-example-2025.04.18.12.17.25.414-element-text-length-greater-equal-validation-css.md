### Element Text Length GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the CSS selector `#content` is greater than or equal to 255 characters.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than or equal to 255.

- **Rule Purpose**: Check that the visible text length of the element #content is at least 255 characters  
- **Type**: Action  
- **Argument**: Verify that element text length meets or exceeds a threshold  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: GreaterEqual - The text length must be greater than or equal to the expected value  
    - **Expected**: 255 - The minimum required length of the element's visible text  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:255}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
