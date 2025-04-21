### Element Count Lower Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the number of elements matching the Xpath selector `//button` is lower than 2.  
If the element count is less than 2, the assert evaluates to `true`.

- **Rule Purpose**: Check if the number of elements found by the Xpath selector is less than 2  
- **Type**: Action  
- **Argument**: Verify element count is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementCount - Counts elements matching the locator  
    - **Operator**: Lower - Checks if the count is less than the expected number  
    - **Expected**: 2 - The threshold number to compare against  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Lower --Expected:2}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
