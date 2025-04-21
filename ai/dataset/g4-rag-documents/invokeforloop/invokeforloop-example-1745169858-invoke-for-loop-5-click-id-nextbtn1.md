### Click Next Button 5 Times Using Id Locator

This example demonstrates how the InvokeForLoop plugin runs a loop 5 times and performs a Click action on the element with Id `NextBtn1` each iteration.  
The inner rule uses `NextBtn1` scoped by Id to locate the target button.  
If no element is found, an exception is logged and the iteration continues. If a Click action throws an exception, it is recorded and the loop proceeds. The process does not stop unless configured to stop on error.

- **Rule Purpose**: Repeat clicking the button with Id "NextBtn1" five times using a loop  
- **Type**: Action  
- **Argument**: 5  
- **Plugin Name**: InvokeForLoop  
- **Rules**: [{"$type":"Action","locator":"Id","onElement":"NextBtn1","pluginName":"Click"}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "5",
  "pluginName": "InvokeForLoop",
  "rules": [
    {
      "$type": "Action",
      "locator": "Id",
      "onElement": "NextBtn1",
      "pluginName": "Click"
    }
  ]
}
```
