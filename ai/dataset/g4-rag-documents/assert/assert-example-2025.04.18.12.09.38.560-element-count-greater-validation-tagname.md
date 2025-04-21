### Element Count Greater Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements with the tag name `button` is greater than 2.  
If the element count exceeds 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that there are more than 2 button elements on the page  
- **Type**: Action  
- **Argument**: Verify element count is greater than 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: Greater - Compares if the count is greater than the expected number  
    - **Expected**: 2 - The minimum number of elements required  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Greater --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
