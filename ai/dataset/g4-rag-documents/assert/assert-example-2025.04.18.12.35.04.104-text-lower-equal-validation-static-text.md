### Text LowerEqual Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `10` is lower than or equal to the expected value 10.  
The validation uses the full provided text string, interpreting it as a numeric value.  
The assertion passes only if that numeric value is lower than or equal to 10; otherwise, it fails.

- **Rule Purpose**: Check if the given text value is less than or equal to 10  
- **Type**: Action  
- **Argument**: Compare text value to be lower or equal to 10  
  - **Parameters**:  
    - **Condition**: Text - Compares text content  
    - **Operator**: LowerEqual - Checks if value is less than or equal to expected  
    - **Expected**: 10 - The numeric threshold for comparison  
- **On Element**: 10  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:LowerEqual --Expected:10}}",
  "onElement": "10",
  "pluginName": "Assert"
}
```
