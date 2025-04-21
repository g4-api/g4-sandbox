Question: How do I define a Click action inside the InvokeForEachLoop?
Answer: Add a child rule with "$type": "Action", "pluginName": "Click", and set onElement to "." to act on the current loop item.
