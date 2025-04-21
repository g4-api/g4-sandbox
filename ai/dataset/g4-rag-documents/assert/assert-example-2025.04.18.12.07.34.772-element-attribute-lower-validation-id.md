### Element Attribute Lower Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than a given value using the Id locator.  
It asserts that the attribute `index` of the element with Id `elementId` is lower than `0` using the Lower operator.  
If the attribute value is lower than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the attribute 'index' of a specified element is less than zero  
- **Type**: Action  
- **Argument**: Verify attribute comparison is lower than expected value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an element's attribute value  
    - **Operator**: Lower - Compares if the attribute value is less than the expected  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Lower --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
