### Element Attribute Regex Match Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the attribute `index` of an element matches the regex pattern `^\d+$`.  
It asserts that the attribute value conforms to the pattern using the Match operator with an Xpath locator.  
If the attribute value matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's 'index' attribute matches a numeric pattern using regex  
- **Type**: Action  
- **Argument**: Verify attribute matches regex pattern  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks a specific attribute of an element  
    - **Operator**: Match - Uses regex matching to compare values  
    - **Expected**: ^\d+$ - The regex pattern that the attribute value must match (one or more digits)  
- **Locator**: Xpath  
- **On Attribute**: index  
- **On Element**: //*[@id='elementId']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:^\\d+$}}",
  "locator": "Xpath",
  "onAttribute": "index",
  "onElement": "//*[@id='elementId']",
  "pluginName": "Assert"
}
```
