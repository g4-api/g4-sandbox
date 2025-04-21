### Element Attribute Greater Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than a given value using the Id locator.  
It asserts that the attribute `index` of the element with Id `elementId` is greater than `0` using the Greater operator.  
If the attribute value is greater than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is greater than zero  
- **Type**: Action  
- **Argument**: Verify that an element attribute is greater than a specified value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: Greater - Compares if the attribute value is greater than the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Greater --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
