### Element Attribute NotEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that a specified attribute of an element is not equal to a given value using the NotEqual operator.  
It asserts that the attribute `index` of the element identified by the Xpath selector `//*[@id='elementId']` is not equal to `0`.  
If the attribute value does not equal `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute 'index' is not equal to 0  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify attribute value is not equal to expected  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of a specified element  
    - **Operator**: NotEqual - Confirms the attribute value is not equal to the expected value  
    - **Expected**: 0 - The value that the attribute should not match  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:NotEqual --Expected:0}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
