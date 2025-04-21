Question: What happens when a loop exceeds its timeout?
Answer: InvokeWhileLoop checks the Timeout parameter along with the condition and will gracefully exit the loop when the specified timeout is reached; if no timeout is set, the loop may run indefinitely.
