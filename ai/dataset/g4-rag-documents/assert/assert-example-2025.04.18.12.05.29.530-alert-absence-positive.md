### Alert Absence Check

This example shows how the Assert plugin verifies that no alert is present.  
If no alert is detected, the assert evaluates to `true`.

- **Rule Purpose**: Check that no native alert is currently showing on the page  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if no native alert is present  
  - **Parameters**:  
    - **Condition**: AlertNotExists - Detects whether no native browser alert is open

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:AlertNotExists}}",
  "pluginName": "Assert"
}
```
