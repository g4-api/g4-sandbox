### Element Text Length LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the visible text of the element identified by the CSS selector `#content` is less than or equal to 100 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
A regular expression `(?s)^(?=.{0,100}$)(.*)$` is applied to the visible text to capture the entire text only if its length is at most 100 characters; if the text exceeds 100 characters, the regex fails to match.  
The assertion passes only if the regex successfully captures text and the computed length is less than or equal to 100 characters.

- **Rule Purpose**: Verify that the visible text length of the element selected by CSS is at most 100 characters  
- **Type**: Action  
- **Argument**: Check if element text length is less than or equal to 100  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's visible text  
    - **Operator**: LowerEqual - Verifies the length is less than or equal to the expected value  
    - **Expected**: 100 - The maximum allowed length of the text  
- **Locator**: CssSelector  
- **On Element**: #content  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(?=.{0,100}$)(.*)$  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:100}}",
  "locator": "CssSelector",
  "onElement": "#content",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(?=.{0,100}$)(.*)$"
}
```
