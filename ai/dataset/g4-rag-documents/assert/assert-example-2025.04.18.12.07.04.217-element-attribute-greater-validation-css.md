### Element Attribute Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than a given value.  
It asserts that the attribute `index` of the element identified by the CSS selector `#elementId` is greater than `0` using the Greater operator.  
If the attribute value is greater than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is greater than zero  
- **Type**: Action  
- **Argument**: Verify attribute comparison is greater than expected value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: Greater - Compares if the attribute value is greater than the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Greater --Expected:0}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
