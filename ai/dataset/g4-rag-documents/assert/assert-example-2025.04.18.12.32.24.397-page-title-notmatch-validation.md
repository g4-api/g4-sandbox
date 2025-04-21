### Page Title NotMatch Validation

This example demonstrates how the Assert plugin verifies that the computed page title does not match the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the page title, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the page title to test for a non-match.  
The assertion passes only if the page title does not match the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Verify that the page title does not match the specified pattern  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check that the page title does not match the pattern `^Lorem ipsum dolor.*`  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title as the value to check  
    - **Operator**: NotMatch - Validates that the value does not match the expected pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to test against the page title

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:NotMatch --Expected:^Lorem ipsum dolor.*}}",
  "pluginName": "Assert"
}
```
