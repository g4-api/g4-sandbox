### Element Text Length GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the CSS selector `#content` is greater than or equal to 100 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the visible text to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length is greater than or equal to 100; if fewer than 100 characters are captured, the assertion fails.

- **Rule Purpose**: Check that the visible text length of the element #content is at least 100 characters  
- **Type**: Action  
- **Argument**: Verify that element text length is greater or equal to 100 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: GreaterEqual - Tests if the length is greater than or equal to the expected value  
    - **Expected**: 100 - The minimum number of characters required  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,100})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:GreaterEqual --Expected:100}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,100})"
}
```
