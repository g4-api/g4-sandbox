### Page URL NotEqual Validation

This example demonstrates how the Assert plugin verifies that the current page URL is not equal to the expected URL `https://example42.com/page/`.  
The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
The assertion passes only if the page URL differs from `https://example42.com/page/`; otherwise, it fails.

- **Rule Purpose**: Check that the current page URL is not equal to a specific URL  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify the page URL is not equal to the expected URL  
  - **Parameters**:  
    - **Condition**: PageUrl - Uses the current page URL for validation  
    - **Operator**: NotEqual - Checks that the actual URL is different from the expected  
    - **Expected**: https://example42.com/page/ - The URL to compare against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:NotEqual --Expected:https://example42.com/page/}}",
  "pluginName": "Assert"
}
```
