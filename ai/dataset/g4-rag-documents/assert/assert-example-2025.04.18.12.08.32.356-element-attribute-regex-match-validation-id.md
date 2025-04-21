### Element Attribute Regex Match Validation Using Id

This example demonstrates how the Assert plugin verifies that the attribute `index` of an element matches the regex pattern `^\d+$`.  
It asserts that the attribute value for the element with Id `elementId` conforms to the pattern using the Match operator.  
If the attribute value matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's 'index' attribute matches a numeric pattern using a regular expression  
- **Type**: Action  
- **Argument**: Verify attribute matches regex pattern  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: Match - Uses regex matching  
    - **Expected**: ^\d+$ - The regex pattern to match digits only  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:^\\d+$}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
