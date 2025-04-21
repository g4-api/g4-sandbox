### Click Each Pagination Button Using CSS Selector

This example demonstrates how the InvokeForEachLoop plugin iterates over each button element matching the CSS selector `#Pagination1 > li > button` and performs a Click action on each.  
The inner rule uses `.` to refer to the current element in the loop context.  
If no buttons are found, an exception is added and the loop is skipped.  
If a Click action fails on any element, an exception is recorded and execution continues to the next element.  
The overall process does not stop unless explicitly configured to stop on error.

- **Rule Purpose**: Loop through each pagination button found by the CSS selector and click it.  
- **Type**: Action  
- **Locator**: CssSelector  
- **On Element**: #Pagination1 > li > button  
- **Plugin Name**: InvokeForEachLoop  
- **Rules**: [{"$type":"Action","onElement":".","pluginName":"Click"}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "locator": "CssSelector",
  "onElement": "#Pagination1 > li > button",
  "pluginName": "InvokeForEachLoop",
  "rules": [
    {
      "$type": "Action",
      "onElement": ".",
      "pluginName": "Click"
    }
  ]
}
```
