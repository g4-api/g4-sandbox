### Debugging Point Using NoAction Plugin

This example demonstrates how the NoAction plugin logs a debugging point labeled `Debugging Point` without performing any operations.  
No action is performed; the plugin simply records the debugging event.  
Use this to insert non-invasive debug markers in the workflow.

- **Rule Purpose**: Log a debugging point without performing any action  
- **Type**: Action  
- **Argument**: Debugging Point  
- **Plugin Name**: NoAction  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "Debugging Point",
  "pluginName": "NoAction"
}
```
