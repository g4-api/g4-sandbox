### Click Next Button 5 Times Using XPath

This example demonstrates how the InvokeForLoop plugin runs a loop 5 times and performs a Click action on the element matching the XPath selector `//button[@id='NextBtn1']` each iteration.  
The inner rule uses the XPath `//button[@id='NextBtn1']` to locate the target button.  
If no element is found, an exception is logged and the iteration continues. If a Click action throws an exception, it is recorded and the loop proceeds. The process does not stop unless configured to stop on error.

- **Rule Purpose**: Repeat clicking the button with id 'NextBtn1' five times using a loop  
- **Type**: Action  
- **Argument**: 5  
- **Plugin Name**: InvokeForLoop  
- **Rules**: [{"$type":"Action","onElement":"//button[@id='NextBtn1']","pluginName":"Click"}]  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "5",
  "pluginName": "InvokeForLoop",
  "rules": [
    {
      "$type": "Action",
      "onElement": "//button[@id='NextBtn1']",
      "pluginName": "Click"
    }
  ]
}
```
