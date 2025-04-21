### Element Attribute LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is lower than or equal to a given value using the Xpath locator.  
It asserts that the attribute `index` of the element identified by the Xpath selector `//*[@id='elementId']` is lower than or equal to `0` using the LowerEqual operator.  
If the attribute value is lower than or equal to `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value is less than or equal to zero  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify attribute comparison with LowerEqual operator  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute value of an element  
    - **Operator**: LowerEqual - Verifies the attribute is less than or equal to the expected value  
    - **Expected**: 0 - The value to compare the attribute against  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:LowerEqual --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
