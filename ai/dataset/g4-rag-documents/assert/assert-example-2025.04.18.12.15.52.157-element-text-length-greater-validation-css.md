### Element Text Length Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the CSS selector `#content` is greater than 255 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than 255.

- **Rule Purpose**: Verify that the visible text length of the element selected by CSS is greater than 255 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater than expected value  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: Greater - Verifies the length is greater than the expected number  
    - **Expected**: 255 - The minimum length required for the assertion to pass  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:255}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
