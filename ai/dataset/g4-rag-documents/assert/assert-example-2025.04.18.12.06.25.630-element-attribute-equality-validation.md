### Element Attribute Equality Validation

This example demonstrates how the Assert plugin verifies that a specified attribute of an element equals a given value.  
It asserts that the attribute `index` of the element identified by the CSS selector `#elementId` is equal to `0` using the Equal operator.  
If the attribute value exactly equals `0`, the assert evaluates to `true`.

- **Rule Purpose**: Check that the element's attribute 'index' exactly equals 0  
- **Type**: Action  
- **Argument**: Verify element attribute equality  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute value of an element  
    - **Operator**: Equal - Compares attribute value for equality  
    - **Expected**: 0 - The expected attribute value to match  
- **Locator**: CssSelector  
- **On Attribute**: index  
- **On Element**: #elementId  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Equal --Expected:0}}",
  "locator": "CssSelector",
  "onAttribute": "index",
  "onElement": "#elementId",
  "pluginName": "Assert"
}
```
