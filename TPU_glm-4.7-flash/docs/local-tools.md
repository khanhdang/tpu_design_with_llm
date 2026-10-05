# Local model tool use

Use only the tools actually provided by the current OpenCode session, with
their exact names and argument schemas. Never invent a tool name or translate
a name into a JavaScript expression such as tools.git["read-file"].
File reading is not a Git operation. Select the available file-reading tool
from the current tool list, or use the available shell tool to read a file.
Use the current file-editing tools to modify files and the current shell tool
to execute make. Emit native tool calls rather than code describing a call.
If a tool call is rejected, inspect the available tools and retry with a valid
name and arguments. If no suitable tool exists, report the limitation and stop.
