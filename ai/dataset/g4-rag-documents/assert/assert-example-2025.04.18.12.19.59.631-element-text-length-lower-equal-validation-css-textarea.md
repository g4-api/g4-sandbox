### Textarea Value Text Length LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text of a textarea's value attribute, identified by the CSS selector `textarea#content`, is less than or equal to 100 characters.  
A regular expression `(?s)^(.{0,100})` is applied to the value attribute to extract only the first 100 characters, so that even if the full text is longer, only these 100 characters are evaluated.  
The assertion passes only if the computed length from this capture group is less than or equal to 100 characters; otherwise, it fails.

- **Rule Purpose**: Verify that the text length of a textarea's value attribute is at most 100 characters  
- **Type**: Action  
- **Argument**: Check if the element's text length is less than or equal to 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: LowerEqual - Verifies the length is less than or equal to the expected value  
    - **Expected**: 100 - The maximum allowed length of the text  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: textarea#content  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:100}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "textarea#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
