### InvokeWhileLoop with Timeout for Active-Class Check

This example demonstrates how the InvokeWhileLoop plugin repeatedly checks the `class` attribute of the element matching XPath `//ul[@id='Pagination1']/li/button[.='6']`, and while it matches the regex `(?i)foo`, performs a Click action on the element matching CSS selector `#NextBtn1`.  
A regular expression `(?i)foo` is applied to the `class` attribute to check for a case-insensitive match with a timeout of 5000 milliseconds per iteration.  
The loop continues until the condition no longer holds or if configured to stop on error.  
All conditions supported by Assert plugins (plugins with `Assert` as their plugin type) can be used here as well to control the loop.

- **Rule Purpose**: Repeatedly check an element's class attribute for a regex match and click a button while the condition is true  
- **Type**: Action  
- **Argument**: Check if an element attribute matches a pattern with timeout  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute of an element against a condition  
    - **Operator**: Match - Uses regex matching for the attribute value  
    - **Expected**: (?i)foo - Case-insensitive regex pattern to match the attribute value  
    - **Timeout**: 5000 - Maximum wait time in milliseconds for each check  
- **On Attribute**: class  
- **On Element**: //ul[@id='Pagination1']/li/button[.='6']  
- **Plugin Name**: InvokeWhileLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn1","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:(?i)foo --Timeout:5000}}",
  "onAttribute": "class",
  "onElement": "//ul[@id='Pagination1']/li/button[.='6']",
  "pluginName": "InvokeWhileLoop",
  "rules": [
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "#NextBtn1",
      "pluginName": "Click"
    }
  ]
}
```
