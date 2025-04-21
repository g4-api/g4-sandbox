### Driver Type Regex NotMatch Validation

This example demonstrates how the Assert plugin verifies that the driver's type does not match a regular expression pattern.  
It asserts that the actual driver's type does not conform to the regex pattern `.*ChromeDriver` using the NotMatch operator.  
If the actual value does not match the regular expression, the assert evaluates to `true`.

- **Rule Purpose**: Verify that the driver type name does not match the pattern ".*ChromeDriver"  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the driver type name does not match the regex pattern  
  - **Parameters**:  
    - **Condition**: DriverTypeName - Checks the type name of the driver in use  
    - **Expected**: .*ChromeDriver - The regex pattern that should not match the driver type  
    - **Operator**: NotMatch - Asserts that the actual value does not match the expected pattern

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:DriverTypeName --Expected:.*ChromeDriver --Operator:NotMatch}}",
  "pluginName": "Assert"
}
```
