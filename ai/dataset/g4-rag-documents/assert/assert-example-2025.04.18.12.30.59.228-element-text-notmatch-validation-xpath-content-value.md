### Element Text NotMatch Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the Xpath locator `//textarea[@id='content']` does not match the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the text from the `value` attribute to test for a non-match.  
The assertion passes only if the text from the `value` attribute does not match the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the textarea's value attribute does not match the specified pattern.  
- **Type**: Action  
- **Argument**: Check that the element text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element or attribute  
    - **Operator**: NotMatch - Validates that the text does not match the given pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to test against  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsum dolor.*}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert"
}
```
