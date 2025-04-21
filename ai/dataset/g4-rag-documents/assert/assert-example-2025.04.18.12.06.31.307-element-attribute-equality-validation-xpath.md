### Element Attribute Equality Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element equals a given value using the Xpath locator.  
It asserts that the attribute `index` of the element identified by the Xpath `//*[@id='elementId']` is equal to `0` using the Equal operator.  
If the attribute value exactly equals `0`, the assert evaluates to `true`.

- **Rule Purpose**: Verify that the element's attribute equals the expected value  
- **Type**: Action  
- **Argument**: Check if an element attribute equals a specific value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks the value of a specified attribute on an element  
    - **Operator**: Equal - Compares the attribute value for equality  
    - **Expected**: 0 - The expected attribute value to compare against  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Equal --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
