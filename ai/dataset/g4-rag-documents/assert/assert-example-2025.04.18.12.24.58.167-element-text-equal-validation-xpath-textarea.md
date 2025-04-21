### Element Text Equal Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the `value` attribute of the element identified by the XPath locator `//textarea[@id='content']` is equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'.  
The validation is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
The assertion passes if the text exactly matches the expected value; otherwise, it fails.

- **Rule Purpose**: Verify that the text in the value attribute of a specific element exactly matches the expected string  
- **Type**: Action  
- **Argument**: Check if element text equals expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Equal - Compares text for exact equality  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The exact text expected in the element  
- **Locator**: Xpath  
- **On Attribute**: value  
- **On Element**: //textarea[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Equal --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "Xpath",
  "onAttribute": "value",
  "onElement": "//textarea[@id='content']",
  "pluginName": "Assert"
}
```
