### Element Attribute NotMatch Regex Validation Using Id

This example demonstrates how the Assert plugin verifies that the attribute `index` of an element does not match the regex pattern `^[a-zA-Z]+$`.  
It asserts that the attribute value for the element with Id `elementId` fails to conform to the pattern using the NotMatch operator.  
If the attribute value does not match the regex pattern, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute value does not match the specified regex pattern  
- **Type**: Action  
- **Argument**: Verify attribute does not match regex pattern  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element  
    - **Operator**: NotMatch - Asserts the attribute value does not match the pattern  
    - **Expected**: ^[a-zA-Z]+$ - The regex pattern the attribute value should not match  
- **Locator**: Id  
- **On Attribute**: index  
- **On Element**: elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:NotMatch --Expected:^[a-zA-Z]+$}}",
  "locator": "Id",
  "onAttribute": "index",
  "onElement": "elementId",
  "pluginName": "Assert"
}
```
