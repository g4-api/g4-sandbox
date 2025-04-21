### Driver Type Mismatch Validation

This example demonstrates how the Assert plugin verifies that the driver's type does not match the expected value using a not-equal operator.  
It asserts that the actual driver's type is different from 'G4.WebDriver.Simulator.SimulatorDriver'.  
If the actual value does not equal the expected value, the assert evaluates to `true`.

- **Rule Purpose**: Verify that the driver type is not 'G4.WebDriver.Simulator.SimulatorDriver'  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check that the driver type is not equal to a specific value  
  - **Parameters**:  
    - **Condition**: DriverTypeName - Checks the type name of the current driver  
    - **Expected**: G4.WebDriver.Simulator.SimulatorDriver - The driver type to compare against  
    - **Operator**: NotEqual - Asserts the actual value is different from the expected

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:DriverTypeName --Expected:G4.WebDriver.Simulator.SimulatorDriver --Operator:NotEqual}}",
  "pluginName": "Assert"
}
```
