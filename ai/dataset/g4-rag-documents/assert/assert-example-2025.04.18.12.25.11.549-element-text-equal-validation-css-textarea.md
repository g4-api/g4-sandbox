### Element Text Equal Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the element identified by the CssSelector `textarea#content` is equal to the expected text 'Lorem ipsu'.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the text content to extract up to 10 characters into a capture group.  
The assertion passes if the extracted text exactly matches the expected value; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the value attribute of a specific element matches the expected text exactly.  
- **Type**: Action  
- **Argument**: Check if element text equals expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Equal - Compares text for exact equality  
    - **Expected**: Lorem ipsu - The text expected to match  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Equal --Expected:Lorem ipsu}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
