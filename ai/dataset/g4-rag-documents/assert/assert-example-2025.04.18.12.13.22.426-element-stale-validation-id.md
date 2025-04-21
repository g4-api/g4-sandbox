### Element Stale Validation Using Id

This example demonstrates how the Assert plugin verifies that the element with the Id `username` is stale.  
If the element is stale, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element identified by Id "username" is no longer attached to the page  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if an element is stale  
  - **Parameters**:  
    - **Condition**: ElementStale - Verifies that the specified element is no longer present or attached in the DOM  
- **Locator**: Id  
- **On Element**: username  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementStale}}",
  "locator": "Id",
  "onElement": "username",
  "pluginName": "Assert"
}
```
