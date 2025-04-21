### Text Lower Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `5` is lower than the expected value 10.  
The validation uses the full provided text string, interpreting it as a numeric value.  
The assertion passes only if that numeric value is lower than 10; otherwise, it fails.

- **Rule Purpose**: Check if the given text value is numerically lower than 10  
- **Type**: Action  
- **Argument**: Validate that text is lower than expected value  
  - **Parameters**:  
    - **Condition**: Text - Checks the text content  
    - **Operator**: Lower - Compares if the value is less than the expected  
    - **Expected**: 10 - The numeric threshold for comparison  
- **On Element**: 5  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Lower --Expected:10}}",
  "onElement": "5",
  "pluginName": "Assert"
}
```
