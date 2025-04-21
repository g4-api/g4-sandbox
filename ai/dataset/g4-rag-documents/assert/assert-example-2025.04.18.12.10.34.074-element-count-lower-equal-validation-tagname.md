### Element Count LowerEqual Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements with the tag name `button` is lower than or equal to 2.  
If the element count is lower than or equal to 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that there are at most 2 button elements on the page  
- **Type**: Action  
- **Argument**: Verify element count is lower or equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementCount - Counts elements matching the locator  
    - **Operator**: LowerEqual - Checks if count is less than or equal to expected  
    - **Expected**: 2 - The maximum allowed number of elements  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:LowerEqual --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
