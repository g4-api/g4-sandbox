### Element Text Equal Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the CssSelector `div#content` is equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
The assertion passes if the element text exactly matches the expected value; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the specified element exactly matches the expected text  
- **Type**: Action  
- **Argument**: Check if element text equals expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Equal - Compares text for exact equality  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The exact text expected in the element  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Equal --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert"
}
```
