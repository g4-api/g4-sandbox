### Page Title Equal Validation

This example demonstrates how the Assert plugin verifies that the computed page title is equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'.  
The validation is based solely on the page title, excluding any HTML markup or tags.  
The assertion passes only if the page title exactly matches the expected text; otherwise, it fails.

- **Rule Purpose**: Verify that the page title exactly matches the expected text  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the page title equals the expected text  
  - **Parameters**:  
    - **Condition**: PageTitle - Checks the current page title text  
    - **Operator**: Equal - Compares the page title for exact equality  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The exact text expected as the page title

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Equal --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "pluginName": "Assert"
}
```
