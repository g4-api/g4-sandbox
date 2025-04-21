### Window Count NotEqual Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is not equal to the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows differs from 1; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows is not equal to 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify window count is not equal to expected value  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the number of open browser windows  
    - **Operator**: NotEqual - Compares values to confirm they are different  
    - **Expected**: 1 - The expected number of windows to compare against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:NotEqual --Expected:1}}",
  "pluginName": "Assert"
}
```
