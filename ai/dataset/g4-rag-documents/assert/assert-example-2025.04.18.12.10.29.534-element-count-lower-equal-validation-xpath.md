### Element Count LowerEqual Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the number of elements matching the Xpath selector `//button` is lower than or equal to 2.  
If the element count is lower than or equal to 2, the assert evaluates to `true`.

- **Rule Purpose**: Check that the number of elements found by the Xpath selector is at most 2  
- **Type**: Action  
- **Argument**: Verify element count is lower or equal to 2  
  - **Parameters**:  
    - **Condition**: ElementCount - Checks how many elements match the locator  
    - **Operator**: LowerEqual - Verifies the count is less than or equal to the expected number  
    - **Expected**: 2 - The maximum allowed number of matching elements  
- **Locator**: Xpath  
- **On Element**: //button  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementCount --Operator:LowerEqual --Expected:2}}",
  "locator": "Xpath",
  "onElement": "//button",
  "pluginName": "Assert"
}
```
