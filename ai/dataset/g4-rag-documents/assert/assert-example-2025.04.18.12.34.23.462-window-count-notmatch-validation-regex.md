### Window Count NotMatch Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows, when converted to a string, does not match the expected pattern `^1\d+?$`.  
The validation is based solely on the count of open browser windows, converted to a string.  
A regular expression `^1\d+?$` is applied to the string representation of the window count to test for a non-match.  
The assertion passes only if the string representation of the window count does not match the pattern `^1\d+?$`; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows as a string does not match the pattern ^1\d+?$.  
- **Type**: Action  
- **Argument**: Validate window count does not match a pattern  
  - **Parameters**:  
    - **Condition**: WindowCount - Uses the count of open browser windows  
    - **Operator**: NotMatch - Checks that the value does not match the pattern  
    - **Expected**: ^1\d+?$ - The regex pattern to test against the window count string  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:NotMatch --Expected:^1\\d+?$}}",
  "pluginName": "Assert"
}
```
