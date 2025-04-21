### Element Text NotMatch Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the CssSelector `textarea#content` does not match the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the text from the `value` attribute to test for a non-match.  
The assertion passes only if the text from the `value` attribute does not match the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Check that the text in the value attribute of the specified textarea does not match the given pattern  
- **Type**: Action  
- **Argument**: Validate that element text does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotMatch - Ensures the text does not match the pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regex pattern to test against the element text  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotMatch --Expected:^Lorem ipsum dolor.*}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert"
}
```
