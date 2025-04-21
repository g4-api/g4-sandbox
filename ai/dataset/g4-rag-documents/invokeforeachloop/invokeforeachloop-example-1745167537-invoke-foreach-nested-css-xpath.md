### Nested InvokeForEachLoop With CSS Selector and Relative XPath

This example demonstrates how the InvokeForEachLoop plugin first locates the container matching the CSS selector `.pagination`, then within each container, iterates over child buttons via relative XPath `./li/button` and performs a Click action.  
The inner loop uses `./li/button` to reference the buttons relative to the current container.  
If no outer elements are found, an exception is logged and the outer loop is skipped.  
If no inner elements are found, an exception is logged and the inner loop is skipped.  
If any Click action throws an exception, it is recorded and execution continues.  
The process does not stop unless configured to stop on error.

- **Rule Purpose**: Iterate over elements found by CSS selector `.pagination` and for each, iterate over child buttons using relative XPath to perform click actions.
- **Type**: Action  
- **Locator**: CssSelector  
- **On Element**: .pagination  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","onElement":"./li/button","pluginName":"InvokeForEachLoop","rules":[{"$type":"Action","pluginName":"Click"}]}]  

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
      "onElement": "./li/button",
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
