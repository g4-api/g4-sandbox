### Element Count GreaterEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the number of elements matching the Xpath selector `//button` is greater than or equal to 2.  
If the element count is greater than or equal to 2, the assert evaluates to `true`.

- **Rule Purpose**: Check if there are at least 2 elements matching the given Xpath selector  
- **Type**: Action  
- **Argument**: Verify element count is greater or equal to 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of matching elements  
    - **Operator**: GreaterEqual - Compares if the count is greater than or equal to the expected value  
    - **Expected**: 2 - The minimum number of elements expected  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:GreaterEqual --Expected:2}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
