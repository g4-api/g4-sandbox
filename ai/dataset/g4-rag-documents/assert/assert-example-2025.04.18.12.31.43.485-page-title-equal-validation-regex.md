### Page Title Equal Validation With Extraction

The validation is based solely on the page title, excluding any HTML markup or tags.  
This example demonstrates how the Assert plugin verifies that the computed page title, after extracting up to 10 characters, matches the expected text 'Lorem ipsu'.  
A regular expression `(?s)^(.{0,10})` is applied to the page title to extract up to 10 characters into a capture group.  
The assertion passes only if the extracted 10-character capture group exactly matches 'Lorem ipsu'; otherwise, it fails.

- **Rule Purpose**: Check that the first 10 characters of the page title exactly match 'Lorem ipsu'  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Validate page title equality with expected text  
  - **Parameters**:  
    - **Condition**: PageTitle - Uses the page title as the value to check  
    - **Operator**: Equal - Checks for exact equality  
    - **Expected**: Lorem ipsu - The expected text to match  
- **Regular Expression**: `(?s)^(.{0,10})`

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageTitle --Operator:Equal --Expected:Lorem ipsu}}",
  "pluginName": "Assert",
  "regularExpression": "(?s)^(.{0,10})"
}
```
