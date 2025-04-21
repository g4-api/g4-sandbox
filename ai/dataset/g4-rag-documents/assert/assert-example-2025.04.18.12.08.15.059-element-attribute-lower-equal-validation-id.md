### Element Attribute LowerEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than or equal to a given value using the Id locator.  
It asserts that the attribute `index` of the element with Id `elementId` is lower than or equal to `0` using the LowerEqual operator.  
If the attribute value is lower than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is less than or equal to a specified number  
- **Type**: Action  
- **Argument**: Check if an element attribute is lower or equal to a value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: LowerEqual - Verifies the attribute is less than or equal to the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:LowerEqual --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
