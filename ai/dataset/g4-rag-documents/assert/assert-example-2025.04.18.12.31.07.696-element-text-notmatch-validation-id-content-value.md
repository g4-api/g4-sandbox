### Element Text NotMatch Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the Id `content` does not match the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the text from the `value` attribute to test for a non-match.  
The assertion passes only if the text from the `value` attribute does not match the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Check that the text in the 'value' attribute of the element with Id 'content' does not match the pattern '^Lorem ipsum dolor.*'  
- **Type**: Action  
- **Argument**: Verify that element text does not match a pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotMatch - Validates that the text does not match the expected pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to test against  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsum dolor.*}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
