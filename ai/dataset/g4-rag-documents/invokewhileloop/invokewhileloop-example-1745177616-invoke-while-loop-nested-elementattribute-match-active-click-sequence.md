### Nested InvokeWhileLoop for Two-Level Active-Class Validation

This example demonstrates how the InvokeWhileLoop plugin first checks the `class` attribute of the element matching XPath `//ul[@id='Pagination1']/li/button[.='3']`, and while it matches the regex `(?i)active`, it enters an inner loop that checks the `class` attribute of elements matching XPath `//ul[@id='Pagination2']/li/button[.='3']` and clicks `#NextBtn2` on each inner iteration.  
After the inner loop completes for each outer iteration, it clicks `#FirstBtn2` and then `#NextBtn1`.  
A regular expression `(?i)active` is applied to the `class` attribute in both loops to check for a case-insensitive match.  
The loops continue until their conditions no longer hold or if configured to stop on error.  
All conditions supported by Assert plugins (plugins with `Assert` as their plugin type) can be used here as well to control the loop.

- **Rule Purpose**: Perform nested loops that check if elements have an active class and click navigation buttons accordingly  
- **Type**: Action  
- **Argument**: Check if the element's attribute matches a pattern  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an element's attribute value  
    - **Operator**: Match - Uses regex matching  
    - **Expected**: (?i)active - Case-insensitive match for "active"  
- **On Attribute**: class  
- **On Element**: //ul[@id='Pagination1']/li/button[.='3']  
- **Plugin Name**: InvokeWhileLoop  
- **Rules**: [{"$type":"Action","argument":"{{$ --Condition:ElementAttribute --Operator:Match --Expected:(?i)active}}","onAttribute":"class","onElement":"//ul[@id='Pagination2']/li/button[.='3']","pluginName":"InvokeWhileLoop","rules":[{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn2","pluginName":"Click"}]},{"$type":"Action","locator":"CssSelector","onElement":"#FirstBtn2","pluginName":"Click"},{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn1","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:(?i)active}}",
  "onAttribute": "class",
  "onElement": "//ul[@id='Pagination1']/li/button[.='3']",
  "pluginName": "InvokeWhileLoop",
  "rules": [
    {
      "$type": "Action",
      "argument": "{{$ --Condition:ElementAttribute --Operator:Match --Expected:(?i)active}}",
      "onAttribute": "class",
      "onElement": "//ul[@id='Pagination2']/li/button[.='3']",
      "pluginName": "InvokeWhileLoop",
      "rules": [
        {
          "$type": "Action",
          "locator": "CssSelector",
          "onElement": "#NextBtn2",
          "pluginName": "Click"
        }
      ]
    },
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "#FirstBtn2",
      "pluginName": "Click"
    },
    {
      "$type": "Action",
      "locator": "CssSelector",
      "onElement": "#NextBtn1",
      "pluginName": "Click"
    }
  ]
}
```
