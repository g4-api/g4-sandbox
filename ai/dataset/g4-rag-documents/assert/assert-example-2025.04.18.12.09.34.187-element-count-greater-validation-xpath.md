### Element Count Greater Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the number of elements matching the Xpath selector `//button` is greater than 2.  
If the element count exceeds 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that more than 2 elements matching the Xpath selector exist  
- **Type**: Action  
- **Argument**: Verify element count is greater than expected  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of elements found  
    - **Operator**: Greater - Compares if the count is greater than the expected number  
    - **Expected**: 2 - The threshold number of elements to compare against  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Greater --Expected:2}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
