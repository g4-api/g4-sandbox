### Page URL Equal Validation

This example demonstrates how the Assert plugin verifies that the current page URL is equal to the expected URL `https://example42.com/page/`.  
The validation is based solely on the page URL, excluding any URL fragments or query parameters unless explicitly part of the expected value.  
The assertion passes only if the page URL exactly matches `https://example42.com/page/`; otherwise, it fails.

- **Rule Purpose**: Check that the current page URL exactly matches a specified URL  
- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Verify if the page URL equals the expected value  
  - **Parameters**:  
    - **Condition**: PageUrl - Checks the current page URL  
    - **Operator**: Equal - Compares for exact equality  
    - **Expected**: https://example42.com/page/ - The URL to compare against

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:PageUrl --Operator:Equal --Expected:https://example42.com/page/}}",
  "pluginName": "Assert"
}
```
