### Element Attribute NotMatch Regex Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the attribute `index` of an element does not match the regex pattern `^[a-zA-Z]+$`.  
It asserts that the attribute value fails to conform to the pattern using the NotMatch operator with an Xpath locator.  
If the attribute value does not match the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's 'index' attribute does not match the specified regex pattern  
- **Type**: Action  
- **Argument**: Verify attribute does not match regex pattern  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: NotMatch - Ensures the attribute value does not match the pattern  
    - **Expected**: ^[a-zA-Z]+$ - The regex pattern to test against  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:NotMatch --Expected:^[a-zA-Z]+$}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
