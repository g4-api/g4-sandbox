### Element Text Length NotMatch Validation Using Id

This example demonstrates how the Assert plugin verifies that the computed length of the text from the value attribute of a textarea element with the Id `content` does not match the expected pattern `^15\d+$`.  
The length is based solely on the text from the `value` attribute, excluding any HTML markup or tags.  
A regular expression `(?s)^(.{0,100})` is applied to the value attribute to extract up to 100 characters into a capture group.  
The assertion passes only if the computed length, when converted to a string, does not match the pattern `^15\d+$`.

- **Rule Purpose**: Verify that the length of the text in the value attribute of the element with Id "content" does not match the pattern ^15\d+$.  
- **Type**: Action  
- **Argument**: Check that the element text length does not match the expected pattern  
  - **Parameters**:  
    - **Condition**: ElementTextLength - Checks the length of the element's text content  
    - **Operator**: NotMatch - Validates that the length does not match the given pattern  
    - **Expected**: ^15\d+$ - The regex pattern that the length should not match  
- **Locator**: Id  
- **On Attribute**: value  
- **On Element**: content  
- **Plugin Name**: Assert  

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementTextLength --Operator:NotMatch --Expected:^15\\d+$}}",
  "locator": "Id",
  "onAttribute": "value",
  "onElement": "content",
  "pluginName": "Assert"
}
```
