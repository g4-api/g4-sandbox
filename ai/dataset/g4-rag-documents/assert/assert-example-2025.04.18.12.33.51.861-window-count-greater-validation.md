### Window Count Greater Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is greater than the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows is greater than 1; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows is greater than 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the window count is greater than expected  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the number of open browser windows  
    - **Operator**: Greater - Compares if the actual count is greater than the expected  
    - **Expected**: 1 - The threshold number of windows to compare against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:Greater --Expected:1}}",
  "pluginName": "Assert"
}
```
