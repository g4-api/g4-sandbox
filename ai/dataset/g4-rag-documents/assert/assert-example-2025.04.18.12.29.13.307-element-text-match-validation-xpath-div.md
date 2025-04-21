### Element Text Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the XPath locator `//div[@id='content']` matches the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the visible text to test for a match.  
The assertion passes only if the element text matches the pattern; otherwise, it fails.

- **Rule Purpose**: Check that the visible text of a specified element matches a given pattern  
- **Type**: Action  
- **Argument**: Verify element text matches pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Match - Tests if the text matches the expected pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to match  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Lorem ipsum dolor.*}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
