### Element Attribute LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than or equal to a given value.  
It asserts that the attribute `index` of the element identified by the CSS selector `#elementId` is lower than or equal to `0` using the LowerEqual operator.  
If the attribute value is lower than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is less than or equal to zero  
- **Type**: Action  
- **Argument**: Verify an element attribute against a condition  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute value of an element  
    - **Operator**: LowerEqual - Tests if the attribute value is less than or equal to the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:LowerEqual --Expected:0}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
