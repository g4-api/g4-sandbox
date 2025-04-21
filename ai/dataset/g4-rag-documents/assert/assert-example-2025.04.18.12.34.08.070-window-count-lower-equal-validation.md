### Window Count LowerEqual Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows is lower than or equal to the expected value 1.  
The validation is based solely on the count of open browser windows.  
The assertion passes only if the number of open windows is lower than or equal to 1; otherwise, it fails.

- **Rule Purpose**: Check if the number of open browser windows is less than or equal to 1  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify window count is lower or equal to expected value  
  - **Parameters**:  
    - **Condition**: WindowCount - Checks the number of open browser windows  
    - **Operator**: LowerEqual - Validates that the count is less than or equal to the expected number  
    - **Expected**: 1 - The maximum allowed number of open windows

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:LowerEqual --Expected:1}}",
  "pluginName": "Assert"
}
```
