### Element Count NotEqual Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements matching the TagName selector for `button` is not equal to 2.  
If the element count is different from 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of button elements is not equal to 2  
- **Type**: Action  
- **Argument**: Verify element count is not equal to 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: NotEqual - Compares the count to be different from the expected number  
    - **Expected**: 2 - The number to compare the element count against  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotEqual --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
