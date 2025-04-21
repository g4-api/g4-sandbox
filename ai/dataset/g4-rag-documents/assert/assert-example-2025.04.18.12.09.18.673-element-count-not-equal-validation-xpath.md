### Element Count NotEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the number of elements matching the Xpath selector `//button` is not equal to 2.  
If the element count is different from 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of elements found by the Xpath selector is not equal to 2  
- **Type**: Action  
- **Argument**: Verify element count is not equal to expected value  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: NotEqual - The count must not be equal to the expected number  
    - **Expected**: 2 - The number to compare the element count against  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:NotEqual --Expected:2}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
