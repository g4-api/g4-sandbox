### Element Text LowerEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the CssSelector `div#content` is lower than or equal to the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the element matched by CssSelector is less than or equal to 42  
- **Type**: Action  
- **Argument**: Verify element text is lower or equal to expected number  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate text content of an element  
    - **Operator**: LowerEqual - Check if the extracted value is less than or equal to the expected value  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:LowerEqual --Expected:42}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
