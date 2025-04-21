### Click Each Pagination Button Using CSS Selector

This example demonstrates how the InvokeForEachLoop plugin iterates over each `<li>` element matching the CSS selector `.pagination > li` and performs a Click action on its child button element selected via CSS selector `button`.  
The inner rule uses the CSS selector `button` to reference the button within the current list item.  
If no elements are found, an exception is logged and the loop is skipped.  
If a Click action within any iteration throws an exception, it is recorded and the loop continues.  
The process does not stop unless configured to stop on error.

- **Rule Purpose**: Loop through each pagination list item and click its button element  
- **Type**: Action  
- **Locator**: CssSelector  
- **On Element**: .pagination > li  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"button","pluginName":"Click"}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "locator": "CssSelector",
  "onElement": ".pagination > li",
  "pluginName": "InvokeForEachLoop",
  "rules": [
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "button",
      "pluginName": "Click"
    }
  ]
}
```
