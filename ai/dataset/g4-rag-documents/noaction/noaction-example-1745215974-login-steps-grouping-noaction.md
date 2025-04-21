### Login Steps Grouping Using NoAction Plugin

This example demonstrates how the NoAction plugin serves as a container to group multiple login actions: sending username, sending password, and clicking the login button.  
Each inner action executes in sequence: SendKeys to `#username`, SendKeys to `#password`, then Click `#loginButton`.  
NoAction itself performs no operations; it simply orchestrates the contained actions.  
Useful for logically grouping related steps in the workflow.

- **Rule Purpose**: Group multiple login actions to execute them in sequence without performing any direct operation.  
- **Type**: Action  
- **Argument**: Login Steps  
- **Plugin Name**: NoAction  
- **Rules**: [{"$type":"Action","argument":"Username","locator":"CssSelector","onElement":"#username","pluginName":"SendKeys"},{"$type":"Action","argument":"Password","locator":"CssSelector","onElement":"#password","pluginName":"SendKeys"},{"$type":"Action","locator":"CssSelector","onElement":"#loginButton","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "Login Steps",
  "pluginName": "NoAction",
  "rules": [
    {
      "$type": "Action",
      "argument": "Username",
      "locator": "CssSelector",
      "onElement": "#username",
      "pluginName": "SendKeys"
    },
    {
      "$type": "Action",
      "argument": "Password",
      "locator": "CssSelector",
      "onElement": "#password",
      "pluginName": "SendKeys"
    },
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "#loginButton",
      "pluginName": "Click"
    }
  ]
}
```
