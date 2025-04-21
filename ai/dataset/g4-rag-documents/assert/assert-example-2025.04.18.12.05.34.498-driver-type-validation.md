### Driver Type Validation

This example demonstrates how the Assert plugin verifies the driver's type using an equality check.  
It asserts that the actual driver's type exactly matches the expected value 'G4.WebDriver.Simulator.SimulatorDriver'.  
If the actual value exactly equals the expected value, the assert evaluates to `true`.

- **Rule Purpose**: Check that the driver type exactly matches the expected simulator driver name  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify driver type equality  
  - **Parameters**:  
    - **Condition**: DriverTypeName - Checks the type name of the current driver  
    - **Expected**: G4.WebDriver.Simulator.SimulatorDriver - The exact driver type expected  
    - **Operator**: Equal - Compares actual and expected values for equality

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:DriverTypeName --Expected:G4.WebDriver.Simulator.SimulatorDriver --Operator:Equal}}",
  "pluginName": "Assert"
}
```
