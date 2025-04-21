Question: How does the plugin handle failures such as a missing source parameter?
Answer: It adds an exception to the response and log stream; by default the workflow continues unless it is explicitly configured to stop on errors.
