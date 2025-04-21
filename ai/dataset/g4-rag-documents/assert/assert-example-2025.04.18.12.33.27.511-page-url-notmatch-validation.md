### Page URL NotMatch Validation

The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected pattern.  
This example demonstrates how the Assert plugin verifies that the current page URL does not match the expected pattern `^https://example42.com/page/$`.  
A regular expression `^https://example42.com/page/$` is applied to the page URL to test for a non-match.  
The assertion passes only if the page URL does not match the pattern `^https://example42.com/page/$`; otherwise, it fails.

- **Rule Purpose**: Check that the current page URL does not match a specific pattern  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify the page URL does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: NotMatch - Ensures the URL does not match the pattern  
    - **Expected**: ^https://example42.com/page/$ - The URL pattern to test against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:NotMatch --Expected:^https://example42.com/page/$}}",
  "pluginName": "Assert"
}
```
