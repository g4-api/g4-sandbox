### Element Text Match Validation Using CssSelector

This example demonstrates how the Assert plugin verifies that the computed text from the element identified by the CssSelector `div#content` matches the expected pattern `^Lorem ipsum dolor.*`.  
The validation is based solely on the element's visible text content, excluding any HTML markup or tags.  
A regular expression `^Lorem ipsum dolor.*` is applied to the visible text to test for a match.  
The assertion passes only if the element text matches the pattern; otherwise, it fails.

- **Rule Purpose**: Verify that the visible text of the specified element matches a given pattern using a regular expression  
- **Type**: Action  
- **Argument**: Check if element text matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementText - Checks the text content of an element  
    - **Operator**: Match - Uses a regular expression match for validation  
    - **Expected**: ^Lorem ipsum dolor.* - The regular expression pattern to match against the element text  
- **Locator**: CssSelector  
- **On Element**: div#content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Lorem ipsum dolor.*}}",
  "locator": "CssSelector",
  "onElement": "div#content",
  "pluginName": "Assert"
}
```
