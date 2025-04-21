### Click Each Pagination Button Using CSS Selector and Relative XPath

This example demonstrates how the InvokeForEachLoop plugin iterates over each `<li>` element matching the CSS selector `.pagination > li` and performs a Click action on its child button element selected via relative XPath `./button`.  
The inner rule uses the XPath `./button` to reference the button within the current list item.  
If no elements are found, an exception is logged and the loop is skipped.  
If a Click action within any iteration throws an exception, it is recorded and the loop continues.  
The process does not stop unless configured to stop on error.

- **Rule Purpose**: Iterate over each pagination list item and click its child button  
- **Type**: Action  
- **Locator**: CssSelector  
- **On Element**: .pagination > li  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","onElement":"./button","pluginName":"Click"}]  

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
      "onElement": "./button",
      "pluginName": "Click"
    }
  ]
}
```
