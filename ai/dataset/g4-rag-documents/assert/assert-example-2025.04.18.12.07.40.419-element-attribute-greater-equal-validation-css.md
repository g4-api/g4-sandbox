### Element Attribute GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than or equal to a given value.  
It asserts that the attribute `index` of the element identified by the CSS selector `#elementId` is greater than or equal to `0` using the GreaterEqual operator.  
If the attribute value is greater than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is greater than or equal to a specified number  
- **Type**: Action  
- **Argument**: Validate that an element attribute meets a numeric condition  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: GreaterEqual - Verifies the attribute value is greater than or equal to the expected value  
    - **Expected**: 0 - The minimum value the attribute should have  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:GreaterEqual --Expected:0}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
