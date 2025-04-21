### Element Count GreaterEqual Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements with the tag name `button` is greater than or equal to 2.  
If the element count is greater than or equal to 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that there are at least two elements with the specified tag name on the page  
- **Type**: Action  
- **Argument**: Verify element count is greater or equal to expected number  
  - **Parameters**:  
    - **Condition**: ElementCount - Counts elements matching the locator  
    - **Operator**: GreaterEqual - Checks if count is greater than or equal to expected  
    - **Expected**: 2 - The minimum number of elements required  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:GreaterEqual --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
