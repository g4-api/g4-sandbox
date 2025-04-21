### Element Text NotEqual Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the CssSelector `div#content` is not equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
The assertion passes if the element text does not match the expected value exactly; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the element selected by CssSelector is not exactly the expected text  
- **Type**: Action  
- **Argument**: Check if element text is not equal to the expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of a specified element  
    - **Operator**: NotEqual - Validates that the actual text is different from the expected text  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The text value to compare against  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotEqual --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert"
}
```
