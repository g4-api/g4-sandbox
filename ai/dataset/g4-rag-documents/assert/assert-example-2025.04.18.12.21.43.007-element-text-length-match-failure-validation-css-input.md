### Input Value Text Length Match Validation (Failure Expected) Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of an input element, identified by the CSS selector `input#content`, matches the pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the `value` attribute to extract up to 100 characters into a capture group.  
Because the regex limits the extraction to 100 characters, the computed length will never begin with '15', and therefore the assertion is expected to fail.

- **Rule Purpose**: Verify that the length of the input element's value attribute text matches a specific numeric pattern.  
- **Type**: Action  
- **Argument**: Check if the length of the element's text matches the pattern ^15\d+$  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the text content  
    - **Operator**: Match - Tests if the length matches the expected pattern  
    - **Expected**: ^15\d+$ - The length should start with '15' followed by digits  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: input#content  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Match --Expected:^15\\d+$}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "input#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
