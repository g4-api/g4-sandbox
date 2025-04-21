### Window Count Lower Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is lower than the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows is lower than 1; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows is less than 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the number of windows is lower than expected  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the count of open browser windows  
    - **Operator**: Lower - Verifies the count is less than the expected value  
    - **Expected**: 1 - The threshold number of windows to compare against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:Lower --Expected:1}}",
  "pluginName": "Assert"
}
```
