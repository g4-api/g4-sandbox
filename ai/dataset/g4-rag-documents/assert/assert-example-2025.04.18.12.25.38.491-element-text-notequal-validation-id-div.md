### Element Text NotEqual Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the Id `content` is not equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
The assertion passes if the element text does not exactly match the expected value; otherwise, it fails.

- **Rule Purpose**: Check that the visible text of the element with Id "content" is not exactly the specified text  
- **Type**: Action  
- **Argument**: Verify element text is not equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: NotEqual - Validates that the actual text is different from the expected text  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The text value to compare against  
- **Locator**: Id  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:NotEqual --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "locator": "Id",
  "onElement": "content",
  "pluginName": "Assert"
}
```
