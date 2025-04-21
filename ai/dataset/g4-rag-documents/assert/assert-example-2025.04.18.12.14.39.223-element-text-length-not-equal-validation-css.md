### Element Text Length NotEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the CSS selector `#content` does not equal 255 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is different from 255.

- **Rule Purpose**: Verify that the visible text length of the element #content is not equal to 255 characters  
- **Type**: Action  
- **Argument**: Check that element text length is not equal to 255  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: NotEqual - The length must not be equal to the expected value  
    - **Expected**: 255 - The length value to compare against  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotEqual --Expected:255}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert"
}
```
