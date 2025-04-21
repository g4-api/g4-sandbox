### Click Next Button 5 Times Using CSS Selector

This example demonstrates how the InvokeForLoop plugin runs a loop 5 times and performs a Click action on the element matching the CSS selector `#NextBtn1` each iteration.  
The inner rule uses `#NextBtn1` scoped by CssSelector to locate the target button.  
If no element is found, an exception is logged and the iteration continues. If a Click action throws an exception, it is recorded and the loop proceeds. The process does not stop unless configured to stop on error.

- **Rule Purpose**: Repeat clicking the button identified by CSS selector `#NextBtn1` five times in a loop  
- **Type**: Action  
- **Argument**: 5  
- **Plugin Name**: InvokeForLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn1","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "5",
  "pluginName": "InvokeForLoop",
  "rules": [
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "#NextBtn1",
      "pluginName": "Click"
    }
  ]
}
```
