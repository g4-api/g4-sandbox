### Element Attribute NotEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is not equal to a given value using the NotEqual operator.  
It asserts that the attribute `index` of the element with Id `elementId` is not equal to `0`.  
If the attribute value does not equal `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the attribute 'index' of the element with Id 'elementId' is not equal to 0  
- **Type**: Action  
- **Argument**: Verify attribute is not equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: NotEqual - Confirms the attribute value is not equal to the expected value  
    - **Expected**: 0 - The value that the attribute should not equal  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:NotEqual --Expected:0}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
