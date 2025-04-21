### Purpose

The InvokeForEachLoop plugin finds all elements matching your locator and runs a set of actions on each one. To operate on the entire collection, set onElement to "." and omit the locator. You can also specify a different locator to decide where actions take place. It supports nested loops for multi-level workflows, making it easier to automate repetitive tasks in RPA and automated testing.

### Key Features and Functionality

| Feature                     | Description                                                         |
|-----------------------------|---------------------------------------------------------------------|
| Element Iteration           | Finds all elements matching the locator and loops through each one. |
| Sequential Execution        | Runs actions in order on each element for a clear workflow.         |
| Alternative Locator Support | Lets you specify a different locator for where actions run.         |
| Nested Loop Capability      | Allows loops inside loops for multi-level workflows.                |

### Usages in RPA

| Use Case            | Description                                                                       |
|---------------------|-----------------------------------------------------------------------------------|
| Data Processing     | Process each item in a list by running data entry, validation, or transformation. |
| Batch Operations    | Perform a series of tasks on groups of files, records, or transactions in order.  |
| Dynamic Interaction | Work with UI items created at runtime by clicking, typing, or checking content.   |

### Usages in Automation Testing

| Use Case               | Description                                                                 |
|------------------------|-----------------------------------------------------------------------------|
| Element Verification   | Check each UI element to confirm its state or value matches expectations.   |
| Data-Driven Testing    | Run tests across different data sets by looping through inputs and actions. |
| UI Interaction Testing | Simulate user steps like clicks or form entries on each element.            |
