### Window Count GreaterEqual Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is greater than or equal to the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows is greater than or equal to 1; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows is at least 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify window count is greater or equal to expected  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the number of open browser windows  
    - **Operator**: GreaterEqual - Compares if the count is greater than or equal to the expected value  
    - **Expected**: 1 - The minimum number of windows expected

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:GreaterEqual --Expected:1}}",
  "pluginName": "Assert"
}
```
