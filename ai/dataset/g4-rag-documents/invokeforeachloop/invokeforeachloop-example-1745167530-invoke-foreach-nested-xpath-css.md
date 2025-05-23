### Nested InvokeForEachLoop With XPath and CSS Selectors

This example demonstrates how the InvokeForEachLoop plugin first locates the `<ul>` element matching the XPath selector `//ul[@class='pagination']`, then within each such `<ul>`, iterates over each child `li > button` via CSS selector and performs a Click action.  
The inner loop uses the CSS selector `li > button` to reference the button within the current list item.  
If no outer elements are found, an exception is logged and the outer loop is skipped.  
If no inner elements are found, an exception is logged and the inner loop is skipped.  
If any Click action throws an exception, it is recorded and execution continues.  
The process does not stop unless configured to stop on error.

- **Rule Purpose**: Perform a nested loop to click each button inside list items within pagination lists found by XPath  
- **Type**: Action  
- **On Element**: //ul[@class='pagination']  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"li > button","pluginName":"InvokeForEachLoop","rules":[{"$type":"Action","pluginName":"Click"}]}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "onElement": "//ul[@class='pagination']",
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
