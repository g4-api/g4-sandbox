### Element Text Length Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the CSS selector `#content` is less than 255 characters.  
The length is computed from the visible text only, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than 255; if it is greater than or equal to 255, the assertion fails.

- **Rule Purpose**: Check that the visible text length of the element is less than 255 characters  
- **Type**: Action  
- **Argument**: Verify element text length is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Lower - Compares if the length is less than the expected value  
    - **Expected**: 255 - The maximum allowed length for the element's text  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:255}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
