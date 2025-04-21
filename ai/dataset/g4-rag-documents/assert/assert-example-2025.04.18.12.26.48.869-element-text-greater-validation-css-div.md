### Element Text Greater Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the CssSelector `div#content` is greater than the expected value 42.  
The visible text content is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is greater than 42; otherwise, it fails.

- **Rule Purpose**: Check that the numeric text in the element matched by CssSelector is greater than 42  
- **Type**: Action  
- **Argument**: Verify element text is greater than expected number  
  - **Parameters**:  
    - **Condition**: ElementText - Extract and evaluate element text content  
    - **Operator**: Greater - Check if extracted value is greater than expected  
    - **Expected**: 42 - The numeric threshold to compare against  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Greater --Expected:42}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
