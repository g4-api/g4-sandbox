### Element Text GreaterEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the CssSelector `div#content` is greater than or equal to the expected value 42.  
The visible text content is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than or equal to 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the element matched by CssSelector is at least 42  
- **Type**: Action  
- **Argument**: Verify element text number is greater or equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate text content from an element  
    - **Operator**: GreaterEqual - Check if extracted value is greater than or equal to expected  
    - **Expected**: 42 - The minimum numeric value expected  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:GreaterEqual --Expected:42}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
