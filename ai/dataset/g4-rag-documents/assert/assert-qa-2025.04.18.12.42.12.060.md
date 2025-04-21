Question: Can you provide an example of an assert rule and explain its components?
Answer: Consider the following example:

{
  "$type": "Action",
  "argument": "{{$ --Condition:Text --Operator:Equal --Expected:Success}}",
  "onElement": "{{$Get-Parameter --Name:MyParam --Scope:Session}}",
  "pluginName": "Assert"
}

In this rule, the '$type' field specifies the action type. The 'argument' defines that the text condition must equal 'Success'. The 'onElement' field indicates the source of the text value (which may be dynamically retrieved), and 'pluginName' confirms that this rule applies to the Assert plugin.
