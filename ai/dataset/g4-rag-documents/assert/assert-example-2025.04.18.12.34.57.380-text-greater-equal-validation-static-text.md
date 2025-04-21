### Text GreaterEqual Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `10` is greater than or equal to the expected value 10.  
The validation uses the full provided text string, interpreting it as a numeric value.  
The assertion passes only if that numeric value is greater than or equal to 10; otherwise, it fails.

- **Rule Purpose**: Verify that the given text value is at least 10 in numeric comparison  
- **Type**: Action  
- **Argument**: Check if text value is greater than or equal to 10  
  - **Parameters**:  
    - **Condition**: Text - Compares text values based on the specified operator  
    - **Operator**: GreaterEqual - Checks if the actual value is greater than or equal to the expected value  
    - **Expected**: 10 - The numeric threshold for comparison  
- **On Element**: 10  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:GreaterEqual --Expected:10}}",
  "onElement": "10",
  "pluginName": "Assert"
}
```
