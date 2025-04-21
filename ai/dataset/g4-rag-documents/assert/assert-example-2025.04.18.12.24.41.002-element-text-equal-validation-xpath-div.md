### Element Text Equal Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the XPath locator `//div[@id='content']` is equal to the expected text 'Lorem ipsu'.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,10})` is applied to the element's text content to extract up to 10 characters into a capture group.  
The assertion passes if the element text exactly matches the expected value; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of a specific element matches the expected text exactly  
- **Type**: Action  
- **Argument**: Check if element text equals expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Equal - Compares text for exact equality  
    - **Expected**: Lorem ipsu - The expected text to match  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Equal --Expected:Lorem ipsu}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
