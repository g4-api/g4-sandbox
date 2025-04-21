### Page Title NotEqual Validation

This example demonstrates how the Assert plugin verifies that the computed page title is not equal to the expected text 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.'  
The validation is based solely on the page title, excluding any HTML markup or tags.  
The assertion passes only if the page title differs from the expected text; otherwise, it fails.

- **Rule Purpose**: Verify that the page title is different from a specific expected text  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the page title is not equal to the expected text  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title for validation  
    - **Operator**: NotEqual - Checks that the actual title is not equal to the expected value  
    - **Expected**: Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42. - The text to compare against the page title

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:NotEqual --Expected:Lorem ipsum dolor sit amet, consectetur adipiscing elit. 42.}}",
  "pluginName": "Assert"
}
```
