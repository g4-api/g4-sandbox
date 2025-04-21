### Element Attribute Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than a given value using the Xpath locator.  
It asserts that the attribute `index` of the element identified by the Xpath selector `//*[@id='elementId']` is lower than `0` using the Lower operator.  
If the attribute value is lower than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is less than zero  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify that an element attribute is lower than a specified value  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: Lower - Compares if the attribute is less than the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Lower --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
