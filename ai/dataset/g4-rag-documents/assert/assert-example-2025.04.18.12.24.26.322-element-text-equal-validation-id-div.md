### Element Text Equal Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the Id `content` is equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
The assertion passes if the element text exactly matches the expected value; otherwise, it fails.

- **Rule Purpose**: Check that the text content of the element with Id "content" exactly matches the expected string  
- **Type**: Action  
- **Argument**: Verify element text equals expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Equal - Compares text for exact equality  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The exact text expected in the element  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Equal --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
