### Element Text Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the textarea element identified by the CssSelector `textarea#content` matches the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the text from the `value` attribute to test for a match.  
The assertion passes only if the text from the `value` attribute matches the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Verify that the value attribute text of a specific textarea matches a given pattern  
- **Type**: Action  
- **Argument**: Check if element text matches the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Match - Tests if the text matches the pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to match  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Lorem ipsum dolor.*}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert"
}
```
