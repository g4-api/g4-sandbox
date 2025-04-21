### Text Equal Validation Using Session Parameter Value

This example demonstrates how the Assert plugin verifies that the text value returned by the session parameter `MyParameter` matches the expected value `ExpectedValue`.  
The validation uses the full text value returned by the session parameter, including any whitespace or formatting.  
The assertion passes only if that parameter value exactly matches `ExpectedValue`; otherwise, it fails.

- **Rule Purpose**: Verify that the session parameter text exactly matches the expected value  
- **Type**: Action  
- **Argument**: Check if text equals expected value  
  - **Parameters**:  
    - **Condition**: Text - Checks the text content  
    - **Operator**: Equal - Compares for exact equality  
    - **Expected**: ExpectedValue - The value to compare against  
- **On Element**: macro... Retrieves the session parameter named MyParameter  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Equal --Expected:ExpectedValue}}",
  "onElement": "{{$Get-Parameter --Name:MyParameter --Scope:Session}}",
  "pluginName": "Assert"
}
```
