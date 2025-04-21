### Element Text Length NotEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the Xpath selector `//div[@id='content']` does not equal 255 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is different from 255.

- **Rule Purpose**: Verify that the visible text length of a specific element is not 255 characters  
- **Type**: Action  
- **Argument**: Check if element text length is not equal to 255  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: NotEqual - Asserts that the length is not equal to the expected value  
    - **Expected**: 255 - The text length value to compare against  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotEqual --Expected:255}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
