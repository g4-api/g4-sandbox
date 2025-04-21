### Input Value Text Length Equal Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the text length of the value attribute of an input element (of type text) identified by the CSS selector `input#content` is exactly 150 characters.  
The text length is computed solely from the value attribute, excluding any HTML markup.  
If the value attribute contains exactly 150 characters (regardless of visual presentation), the assert evaluates to `true`.

- **Rule Purpose**: Check that the value attribute text length of a specific input element is exactly 150 characters  
- **Type**: Action  
- **Argument**: Verify text length equals 150 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text or attribute value  
    - **Operator**: Equal - Compares if the length is exactly the expected value  
    - **Expected**: 150 - The exact length expected for the text  
- **Locator**: CssSelector  
- **On Attribute**: value  
- **On Element**: input#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Equal --Expected:150}}",
  "locator": "CssSelector",
  "onAttribute": "value",
  "onElement": "input#content",
  "pluginName": "Assert"
}
```
