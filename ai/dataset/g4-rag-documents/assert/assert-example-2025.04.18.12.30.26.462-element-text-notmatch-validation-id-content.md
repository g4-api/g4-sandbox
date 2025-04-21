### Element Text NotMatch Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the Id `content` does not match the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the visible text to test for a non-match.  
The assertion passes only if the text does not match the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the element with Id "content" does not match the specified pattern.  
- **Type**: Action  
- **Argument**: Check if element text does not match the pattern ^Lorem ipsum dolor.*  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotMatch - Validates that the text does not match the pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to test against  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsum dolor.*}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
