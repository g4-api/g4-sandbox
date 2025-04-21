### Element Count Equal Validation Using TagName

This example demonstrates how the Assert plugin verifies that the number of elements matching the TagName selector is exactly 2.  
It asserts that the element count for elements with tag name `button` equals 2.  
If the element count equals 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that exactly two elements with the specified tag name exist on the page  
- **Type**: Action  
- **Argument**: Verify element count equals 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks the number of matching elements  
    - **Operator**: Equal - Compares if the count is equal to the expected value  
    - **Expected**: 2 - The exact number of elements expected  
- **Locator**: TagName  
- **On Element**: button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:Equal --Expected:2}}",
  "locator": "TagName",
  "onElement": "button",
  "pluginName": "Assert"
}
```
