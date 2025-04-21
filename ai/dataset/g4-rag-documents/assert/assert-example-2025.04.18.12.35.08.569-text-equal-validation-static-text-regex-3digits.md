### Text Equal Validation With Extraction

The validation uses the full provided text string, including any whitespace or formatting.  
This example demonstrates how the Assert plugin verifies that the provided text value `1000`, after applying a regular expression, exactly matches the expected value `100`.  
A regular expression `\d{3}` is applied to the provided text to extract a three-digit numeric sequence into a capture group.  
The assertion passes only if that extracted capture group matches the pattern `100`; otherwise, it fails.

- **Rule Purpose**: Verify that the extracted three-digit number from the text exactly matches "100".  
- **Type**: Action  
- **Argument**: Check if extracted text equals expected value  
  - **Parameters**:  
    - **Condition**: Text - Checks text content against a condition  
    - **Operator**: Equal - Requires exact match between extracted text and expected value  
    - **Expected**: 100 - The value expected to match the extracted text  
- **On Element**: 1000  
- **Plugin Name**: Assert  
- **Regular Expression**: \d{3}  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Equal --Expected:100}}",
  "onElement": "1000",
  "pluginName": "Assert",
  "regularExpression": "\\d{3}"
}
```
