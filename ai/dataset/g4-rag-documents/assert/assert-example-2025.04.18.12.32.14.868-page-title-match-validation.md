### Page Title Match Validation

This example demonstrates how the Assert plugin verifies that the computed page title matches the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the page title, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the page title to test for a match.  
The assertion passes only if the page title matches the pattern `^Lorem ipsum dolor.*`; otherwise, it fails.

- **Rule Purpose**: Check that the page title matches a specific pattern using a regular expression  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify page title matches pattern  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title as the value to check  
    - **Operator**: Match - Tests if the value matches the expected pattern  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to match against the page title

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Match --Expected:^Lorem ipsum dolor.*}}",
  "pluginName": "Assert"
}
```
