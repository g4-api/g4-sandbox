### Nested InvokeForLoop With Mixed Actions

This example demonstrates how the InvokeForLoop plugin runs an outer loop 2 times, then within each outer iteration runs an inner loop 2 times to Click `#NextBtn2`, followed by a Click on `//button[@Id='FirstBtn2']`, then a Click on the element with Id `NextBtn1`.  
Inner loops use their own argument and selectors as specified.  
If any element is missing, an exception is logged and that iteration continues. Click failures record exceptions without stopping the outer loop. The overall process only stops if configured to stop on error.

- **Rule Purpose**: Run nested loops to perform multiple click actions on specified elements, handling exceptions without stopping the entire process  
- **Type**: Action  
- **Argument**: 2  
- **Plugin Name**: InvokeForLoop  
- **Rules**: [{"$type":"Action","argument":"2","pluginName":"InvokeForLoop","rules":[{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn2","pluginName":"Click"}]},{"$type":"Action","onElement":"//button[@Id='FirstBtn2']","pluginName":"Click"},{"$type":"Action","locator":"Id","onElement":"NextBtn1","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "2",
  "pluginName": "InvokeForLoop",
  "rules": [
    {
      "$type": "Action",
      "argument": "2",
      "pluginName": "InvokeForLoop",
      "rules": [
        {
          "$type": "Action",
          "locator": "CssSelector",
          "onElement": "#NextBtn2",
          "pluginName": "Click"
        }
      ]
    },
    {
      "$type": "Action",
      "onElement": "//button[@Id='FirstBtn2']",
      "pluginName": "Click"
    },
    {
      "$type": "Action",
      "locator": "Id",
      "onElement": "NextBtn1",
      "pluginName": "Click"
    }
  ]
}
```
