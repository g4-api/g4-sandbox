### Element Text NotEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the CssSelector `div#content` is not equal to the expected text 'Lorem ipsu'.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the text content to extract up to 10 characters into a capture group.  
The assertion passes if the extracted text does not match the expected value exactly; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the specified element is not exactly 'Lorem ipsu' after applying a text extraction pattern  
- **Type**: Action  
- **Argument**: Check if element text is not equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotEqual - Validates that the text does not match the expected value  
    - **Expected**: Lorem ipsu - The text value to compare against  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotEqual --Expected:Lorem ipsu}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
