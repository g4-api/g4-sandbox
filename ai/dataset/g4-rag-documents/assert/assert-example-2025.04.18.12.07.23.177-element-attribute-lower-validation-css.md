### Element Attribute Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than a given value.  
It asserts that the attribute `index` of the element identified by the CSS selector `#elementId` is lower than `0` using the Lower operator.  
If the attribute value is lower than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is less than zero  
- **Type**: Action  
- **Argument**: Verify that an element attribute is lower than a specified value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: Lower - Compares if the attribute is less than the expected value  
    - **Expected**: 0 - The value to compare against  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Lower --Expected:0}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
