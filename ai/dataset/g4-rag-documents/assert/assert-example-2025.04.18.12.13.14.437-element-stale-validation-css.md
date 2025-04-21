### Element Stale Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the element identified by the CSS selector `#username` is stale.  
If the element is stale, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element identified by the CSS selector #username is no longer attached to the page  
- **Type**: Action  
- **Argument**: Check if an element is stale  
  - **Parameters**:  
    - **Condition**: ElementStale - Verifies that the specified element is no longer present in the DOM  
- **Locator**: CssSelector  
- **On Element**: #username  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementStale}}",
  "locator": "CssSelector",
  "onElement": "#username",
  "pluginName": "Assert"
}
```
