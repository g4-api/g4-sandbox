### Window Count Match Validation

This example demonstrates how the Assert plugin verifies that the computed number of open browser windows, when converted to a string, matches the expected pattern `^1\d+?$`.  
The validation is based solely on the count of open browser windows, converted to a string.  
A regular expression `^1\d+?$` is applied to the string representation of the window count to test for a match.  
The assertion passes only if the string representation of the window count matches the pattern `^1\d+?$`; otherwise, it fails.

- **Rule Purpose**: Check that the number of open browser windows matches a specific pattern starting with 1 followed by digits  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify window count matches pattern  
  - **Parameters**:  
    - **Condition**: WindowCount - Uses the count of open browser windows as the value to check  
    - **Operator**: Match - Tests if the value matches the expected pattern  
    - **Expected**: ^1\d+?$ - The regular expression pattern the window count string must match  
- **Regular Expression**: ^1\d+?$

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:WindowCount --Operator:Match --Expected:^1\\d+?$}}",
  "pluginName": "Assert",
  "regularExpression": "^1\\d+?$"
}
```
