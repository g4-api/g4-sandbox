### Element Attribute GreaterEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is greater than or equal to a given value using the Xpath locator.  
It asserts that the attribute `index` of the element identified by the Xpath selector `//*[@id='elementId']` is greater than or equal to `0` using the GreaterEqual operator.  
If the attribute value is greater than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Verify that the element's attribute value is greater than or equal to a specified number  
- **Type**: Action  
- **Argument**: Check if an element attribute meets a numeric condition  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: GreaterEqual - Verifies the attribute value is greater than or equal to the expected value  
    - **Expected**: 0 - The minimum value the attribute should have  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:GreaterEqual --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
