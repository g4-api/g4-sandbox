### Element Text Length Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the CSS selector `#content` is less than 100 characters.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is less than 100; if 100 or more characters are captured, the assertion fails.

- **Rule Purpose**: Verify that the visible text length of the element selected by CSS is less than 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is lower than 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: Lower - Verifies the length is less than the expected value  
    - **Expected**: 100 - The maximum allowed length of the visible text  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Lower --Expected:100}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
