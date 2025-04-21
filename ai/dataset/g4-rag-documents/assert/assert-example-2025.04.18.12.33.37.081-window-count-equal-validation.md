### Window Count Equal Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is equal to the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows is exactly 1; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows is exactly 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the window count equals 1  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the number of open browser windows  
    - **Operator**: Equal - Compares if the count matches the expected value  
    - **Expected**: 1 - The expected number of open windows

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:Equal --Expected:1}}",
  "pluginName": "Assert"
}
```
