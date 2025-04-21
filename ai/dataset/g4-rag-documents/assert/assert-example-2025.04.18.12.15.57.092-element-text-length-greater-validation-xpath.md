### Element Text Length Greater Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the visible text content of the element identified by the Xpath selector `//div[@id='content']` is greater than 255 characters.  
The length is based solely on the visible text, excluding any HTML markup or tags.  
The assertion passes only if the computed length is greater than 255.

- **Rule Purpose**: Verify that the visible text length of a specified element is greater than 255 characters  
- **Type**: Action  
- **Argument**: Check if element text length is greater than expected value  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Measures the length of the visible text content of an element  
    - **Operator**: Greater - Checks if the actual length is greater than the expected length  
    - **Expected**: 255 - The minimum length required for the assertion to pass  
- **Locator**: Xpath  
- **On Element**: //div[@id='content']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:Greater --Expected:255}}",
  "locator": "Xpath",
  "onElement": "//div[@id='content']",
  "pluginName": "Assert"
}
```
