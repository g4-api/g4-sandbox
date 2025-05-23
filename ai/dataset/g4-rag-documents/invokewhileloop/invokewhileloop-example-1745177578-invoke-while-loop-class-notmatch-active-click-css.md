### Click Next While Not Active Using CSS Selector

This example demonstrates how the InvokeWhileLoop plugin repeatedly checks the `class` attribute of the element matching XPath `//ul[@id='Pagination1']/li/button[.='6']`, and while it does not match the regex `(?i)active`, performs a Click action on the element matching CSS selector `#NextBtn1`.  
A regular expression `(?i)active` is applied to the `class` attribute to check for a case-insensitive match.  
The loop continues until the condition no longer holds or if configured to stop on error.  
All conditions supported by Assert plugins (plugins with `Assert` as their plugin type) can be used here as well to control the loop.

- **Rule Purpose**: Repeatedly click the next button while the specified element's class attribute does not contain "active" (case-insensitive)  
- **Type**: Action  
- **Argument**: Check if element attribute does not match regex "(?i)active"  
  - **Parameters**:  
    - **Condition**: ElementAttribute - Checks an attribute value of an element  
    - **Operator**: NotMatch - The attribute value must not match the expected pattern  
    - **Expected**: (?i)active - Case-insensitive regex pattern to match "active"  
- **On Attribute**: class  
- **On Element**: //ul[@id='Pagination1']/li/button[.='6']  
- **Plugin Name**: InvokeWhileLoop  
- **Rules**: [{"$type":"Action","locator":"CssSelector","onElement":"#NextBtn1","pluginName":"Click"}]

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "argument": "{{$ --Condition:ElementAttribute --Operator:NotMatch --Expected:(?i)active}}",
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
