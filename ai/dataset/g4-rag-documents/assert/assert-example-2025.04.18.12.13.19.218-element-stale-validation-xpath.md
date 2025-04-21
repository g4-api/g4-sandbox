### Element Stale Validation Using Xpath

This example demonstrates how the Assert plugin verifies that the element identified by the Xpath selector `//input[@id='username']` is stale.  
If the element is stale, the assert evaluates to `true`.

- **Rule Purpose**: Check if the element located by the given Xpath is no longer attached to the page  
- **Type**: Action  
- **Argument**: Check if an element is stale  
  - **Parameters**:  
    - **Condition**: ElementStale - Verifies that the specified element is no longer present or attached in the DOM  
- **Locator**: Xpath  
- **On Element**: //input[@id='username']  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementStale}}",
  "locator": "Xpath",
  "onElement": "//input[@id='username']",
  "pluginName": "Assert"
}
```
