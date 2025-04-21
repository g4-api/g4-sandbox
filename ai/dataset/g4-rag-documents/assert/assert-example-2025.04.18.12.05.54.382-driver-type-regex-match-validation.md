### Driver Type Regex Match Validation

This example demonstrates how the Assert plugin verifies that the driver's type matches a regular expression pattern.  
It asserts that the actual driver's type conforms to the regex pattern `.*SimulatorDriver` using the Match operator.  
If the actual value matches the regular expression, the assert evaluates to `true`.

- **Rule Purpose**: Check if the driver type matches the regex pattern `.*SimulatorDriver`  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify driver type matches a pattern  
  - **Parameters**:  
    - **Condition**: DriverTypeName - Checks the name of the driver type  
    - **Expected**: .*SimulatorDriver - The regex pattern to match against the driver type  
    - **Operator**: Match - Uses regex matching to compare values  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:DriverTypeName --Expected:.*SimulatorDriver --Operator:Match}}",
  "pluginName": "Assert"
}
```
