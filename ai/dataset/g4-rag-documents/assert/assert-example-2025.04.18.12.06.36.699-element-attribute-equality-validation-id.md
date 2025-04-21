### Element Attribute Equality Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element equals a given value using the Id locator.  
It asserts that the attribute `index` of the element with Id `elementId` is equal to `0` using the Equal operator.  
If the attribute value exactly equals `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the attribute 'index' of the element with Id 'elementId' equals 0  
- **Type**: Action  
- **Argument**: Verify attribute equality with expected value 0  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an element's attribute value  
    - **Operator**: Equal - Compares attribute value for equality  
    - **Expected**: 0 - The expected attribute value to match  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Equal --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
