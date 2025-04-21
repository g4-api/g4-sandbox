### Nested InvokeForEachLoop With CSS Selectors

This example demonstrates how the InvokeForEachLoop plugin first locates the container matching the CSS selector `.pagination`, then within each container, iterates over child buttons via CSS selector `li > button` and performs a Click action.  
The inner loop uses the CSS selector `li > button` scoped to the current container.  
If no outer elements are found, an exception is logged and the outer loop is skipped.  
If no inner elements are found, an exception is logged and the inner loop is skipped.  
If any Click action throws an exception, it is recorded and execution continues.  
The process does not stop unless configured to stop on error.

- **Rule Purpose**: Perform nested loops over elements found by CSS selectors and click each inner button, handling exceptions without stopping execution  
- **Type**: Action  
- **Locator**: CssSelector  
- **On Element**: .pagination  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"li > button","pluginName":"InvokeForEachLoop","rules":[{"$type":"Action","pluginName":"Click"}]}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "locator": "CssSelector",
  "onElement": ".pagination",
  "pluginName": "InvokeForEachLoop",
  "rules": [
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "li > button",
      "pluginName": "InvokeForEachLoop",
      "rules": [
        {
          "$type": "Action",
          "pluginName": "Click"
        }
      ]
    }
  ]
}
```
