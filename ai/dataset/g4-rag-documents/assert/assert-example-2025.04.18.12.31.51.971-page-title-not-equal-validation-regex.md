### Page Title NotEqual Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the computed page title, after extracting up to 10 characters, does not equal the expected text 'Lorem ipsu'.  
A regular expression `(?s)^(.{0,10})` is applied to the page title to extract up to 10 characters into a capture group.  
The assertion passes only if that extracted 10-character capture group does not equal 'Lorem ipsu'; otherwise, it fails.

- **Rule Purpose**: Verify that the first 10 characters of the page title are not equal to 'Lorem ipsu'  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if the page title does not equal the expected text after extraction  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title as the value to check  
    - **Operator**: NotEqual - Checks that the value is not equal to the expected text  
    - **Expected**: Lorem ipsu - The text that the extracted title should not match  
- **Regular Expression**: (?s)^(.{0,10})

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:NotEqual --Expected:Lorem ipsu}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
