### Element Text Lower Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the numeric value extracted from the visible text content of the element identified by the CssSelector `div#content` is lower than the expected value 42.  
The visible text is processed using the regular expression `\d+` to extract a numeric value.  
The assertion passes if the extracted numeric value is lower than 42; otherwise, it fails.

- **Rule Purpose**: Check if the numeric text extracted from a specific element is less than 42  
- **Type**: Action  
- **Argument**: Verify that extracted number is lower than expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Extracts and evaluates text content from an element  
    - **Operator**: Lower - Checks if the extracted value is less than the expected  
    - **Expected**: 42 - The numeric value to compare against  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  
- **Regular Expression**: \d+

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Lower --Expected:42}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert",
  "regularExpression": "\\d+"
}
```
