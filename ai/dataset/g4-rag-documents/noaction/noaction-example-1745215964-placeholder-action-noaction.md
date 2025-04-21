### Placeholder Action Using NoAction Plugin

This example demonstrates how the NoAction plugin logs execution points without performing any operations, useful for placeholder or debugging checkpoints.  
No action is performed; the plugin simply records the event.  
Use this to mark points in the workflow where no actual action is desired.

- **Rule Purpose**: Mark a point in the workflow without performing any action, useful for placeholders or debugging  
- **Type**: Action  
- **Argument**: This is a Placeholder Action  
- **Plugin Name**: NoAction  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "This is a Placeholder Action",
  "pluginName": "NoAction"
}
```
