### Element Attribute Greater Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than a given value using the Xpath locator.  
It asserts that the attribute `index` of the element identified by the Xpath selector `//*[@id='elementId']` is greater than `0` using the Greater operator.  
If the attribute value is greater than `0`, the assert evaluates to `true`.

- **Rule Purpose**: Verify that the element's attribute value is greater than zero  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element attribute meets a condition  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: Greater - Tests if the attribute value is greater than the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Greater --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
