### Page URL Match Validation

This example demonstrates how the Assert plugin verifies that the current page URL matches the expected pattern `^https://example42.com/page/$`.  
The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected pattern.  
A regular expression `^https://example42.com/page/$` is applied to the page URL to test for a match.  
The assertion passes only if the page URL matches the pattern `^https://example42.com/page/$`; otherwise, it fails.

- **Rule Purpose**: Check if the current page URL matches a specific pattern  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify page URL matches pattern  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: Match - Tests if the URL matches the expected pattern  
    - **Expected**: ^https://example42.com/page/$ - The regular expression pattern to match

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Match --Expected:^https://example42.com/page/$}}",
  "pluginName": "Assert"
}
```
