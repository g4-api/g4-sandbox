### Text Greater Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `20` is greater than the expected value 10.  
The validation uses the full provided text string, interpreting it as a numeric value.  
The assertion passes only if that numeric value is greater than 10; otherwise, it fails.

- **Rule Purpose**: Check if the given text value is greater than 10  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify that text is greater than expected value  
  - **Parameters**:  
    - **Condition**: Text - Checks the text content  
    - **Operator**: Greater - Compares if the actual value is greater than expected  
    - **Expected**: 10 - The numeric threshold to compare against  
- **On Element**: 20  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Greater --Expected:10}}",
  "onElement": "20",
  "pluginName": "Assert"
}
```
