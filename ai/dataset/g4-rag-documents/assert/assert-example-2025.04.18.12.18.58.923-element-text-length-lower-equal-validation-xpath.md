### Element Text Length LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the Xpath selector `//div[@id='content']` is less than or equal to 255 characters.  
The length is determined solely from the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is less than or equal to 255.

- **Rule Purpose**: Check that the visible text length of a specific element is at most 255 characters  
- **Type**: Action  
- **Argument**: Verify that element text length is lower or equal to 255 characters  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the visible text of an element  
    - **Operator**: LowerEqual - Compares if the text length is less than or equal to the expected value  
    - **Expected**: 255 - The maximum allowed length of the element's visible text  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:LowerEqual --Expected:255}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
