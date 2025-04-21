### Element Text NotEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the XPath locator `//div[@id='content']` is not equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
The assertion passes if the element text does not match the expected value exactly; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of a specific element does not exactly match a given expected string  
- **Type**: Action  
- **Argument**: Check that element text is not equal to the expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotEqual - Validates that the actual text is different from the expected text  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The text value to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotEqual --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
