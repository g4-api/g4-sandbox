### Element Attribute Regex Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the attribute `index` of an element matches the regex pattern `^\d+$`.  
It asserts that the attribute value conforms to the pattern using the Match operator.  
If the attribute value matches the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's 'index' attribute matches a numeric pattern  
- **Type**: Action  
- **Argument**: Validate element attribute with regex match  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of a specified element  
    - **Operator**: Match - Uses regex matching to compare values  
    - **Expected**: ^\d+$ - The regex pattern that the attribute value must match (digits only)  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:^\\d+$}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
