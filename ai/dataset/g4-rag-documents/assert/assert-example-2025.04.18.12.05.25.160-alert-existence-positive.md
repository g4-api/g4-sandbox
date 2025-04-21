### Alert Existence Check

This example shows how the Assert plugin verifies that an alert is present.  
If an alert is detected, the assert evaluates to `true`.

- **Rule Purpose**: Check if a native alert is present  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if a native alert is present  
  - **Parameters**:  
    - **Condition**: AlertExists - Detects whether a native browser alert is open

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:AlertExists}}",
  "pluginName": "Assert"
}
```
