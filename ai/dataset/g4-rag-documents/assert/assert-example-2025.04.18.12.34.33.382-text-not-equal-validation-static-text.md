### Text NotEqual Validation With Static Text

This example demonstrates how the Assert plugin verifies that the provided text value `Static Text` does not equal the expected value `Static Text`.  
The validation uses the full provided text string, including any whitespace or formatting.  
The assertion passes only if the provided text value differs from `Static Text`; otherwise, it fails.

- **Rule Purpose**: Verify that the provided text value is not equal to the expected static text  
- **Type**: Action  
- **Argument**: Check that text is not equal to a specific value  
  - **Parameters**:  
    - **Condition**: Text - Checks the text content of an element or value  
    - **Operator**: NotEqual - Validates that the actual text does not match the expected text  
    - **Expected**: Static Text - The text value to compare against  
- **On Element**: Static Text  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:NotEqual --Expected:Static Text}}",
  "onElement": "Static Text",
  "pluginName": "Assert"
}
```
