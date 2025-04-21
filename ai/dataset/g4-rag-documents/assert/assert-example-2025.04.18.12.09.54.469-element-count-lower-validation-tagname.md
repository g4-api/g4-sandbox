### Element Count Lower Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements matching the TagName selector for `button` is lower than 2.  
If the element count is less than 2, the assert evaluates to `true`.

- **Rule Purpose**: Check if the number of button elements is less than 2  
- **Type**: Action  
- **Argument**: Verify element count is lower than expected  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the count of elements matching a locator  
    - **Operator**: Lower - Compares if the actual count is less than the expected count  
    - **Expected**: 2 - The threshold number to compare against  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Lower --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
