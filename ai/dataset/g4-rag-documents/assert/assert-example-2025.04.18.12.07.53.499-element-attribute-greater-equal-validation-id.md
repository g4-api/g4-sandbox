### Element Attribute GreaterEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than or equal to a given value using the Id locator.  
It asserts that the attribute `index` of the element with Id `elementId` is greater than or equal to `0` using the GreaterEqual operator.  
If the attribute value is greater than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check if an element's attribute value is greater than or equal to a specified number  
- **Type**: Action  
- **Argument**: Verify attribute comparison with GreaterEqual operator  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute value of an element  
    - **Operator**: GreaterEqual - Compares if the attribute value is greater than or equal to the expected value  
    - **Expected**: 0 - The minimum value expected for the attribute  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:GreaterEqual --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
