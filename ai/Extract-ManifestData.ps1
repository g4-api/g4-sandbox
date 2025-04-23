param(
    [CmdletBinding()]
    [string]$EmbeddingApiUri = "https://api.openai.com/v1/embeddings",
    [string]$EmbeddingModel  = "text-embedding-ada-002",
    [string]$HubUri          = "http://host.k8s.internal:9944",
    [int]   $MaxTokens       = 6000,
    [string]$PluginKey       = "CopyParameter",
    [string]$PluginType      = "Action",
    [string]$RootPath        = $PSScriptRoot,
    [string]$OpenAiApiKey    = $env:OPEN_AI_API_KEY,
    [string]$OpenAiApiUri    = "https://api.openai.com/v1/chat/completions",
    [string]$OpenAiModel     = "gpt-4.1-mini"
)

function Convert-Description {
    <#
    .SYNOPSIS
    Create a RAG document structure for a plugin description.

    .DESCRIPTION
    This function takes a textual description, its embedding vector, and a plugin key,
    and returns a hashtable containing:
      - A unique document ID
      - A RAG payload with ids, embeddings, metadatas, and documents arrays

    .PARAMETER Document
    The full text of the plugin description to index.

    .PARAMETER Embedding
    A numeric array representing the embedding vector for the document.

    .PARAMETER PluginKey
    The unique key or slug of the plugin (e.g. "Assert"), used to build the document ID.

    .OUTPUTS
    Hashtable with keys:
      - id: the generated document identifier
      - ragDocument: the structured RAG payload

    .EXAMPLE
    $doc  = "The Assert plugin checks that UI elements match expected values."
    $emb  = @(0.12, 0.34, 0.56)
    $out  = Convert-Description -Document $doc -Embedding $emb -PluginKey "Assert"
    # returns a hashtable with .id and .ragDocument
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]  $Document,

        [Parameter(Mandatory = $true)]
        [double[]]$Embedding,

        [Parameter(Mandatory = $true)]
        [string]  $PluginKey
    )

    # Create a high‑precision timestamp to ensure uniqueness
    $dynamicId = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

    # Build the document ID using plugin key and timestamp
    $id = "{0}-description-{1}" -f $PluginKey.ToLower(), $dynamicId

    # Prepare metadata for this description section
    $metadata = @{
        section     = "description"   # identifies which part of the manifest this is
        plugin_name = $PluginKey      # store the plugin key for filtering
    }

    # Wrap the single embedding vector in an array for RAG compatibility
    $nestedEmbeddings = ,$Embedding

    # Assemble the RAG document payload
    $ragDocument = @{
        ids        = @($id)            # list of document ids (only one here)
        embeddings = $nestedEmbeddings # list of embedding arrays
        metadatas  = @($metadata)      # list of metadata hashtables
        documents  = @($Document)      # list of document texts
    }

    # Return a hashtable containing the id and the full RAG payload
    return @{
        id          = $id
        ragDocument = $ragDocument
    }
}

function Convert-Example {
    <#
    .SYNOPSIS
    Create a RAG document structure for a plugin example.

    .DESCRIPTION
    This function takes an example entry, its text, an embedding vector, and a plugin key,
    then returns a hashtable containing:
      - A unique document ID
      - A RAG payload with ids, embeddings, metadatas, and documents arrays

    .PARAMETER Id
    A short identifier for the example (for example "alert-exists").

    .PARAMETER Document
    The full text of the example to index (narrative plus rule block).

    .PARAMETER Embedding
    A numeric array representing the embedding vector for the document.

    .PARAMETER Example
    The original example object, which must include:
      - context.annotations (hashtable of metadata fields)
      - context.labels (array of label strings)

    .PARAMETER PluginKey
    The unique key or slug of the plugin (for example "Assert"),
    used to build the document ID and metadata.

    .OUTPUTS
    Hashtable with keys:
      - id          : the generated document identifier
      - ragDocument : the structured RAG payload

    .EXAMPLE
    $example = @{
        context = @{
            annotations = @{
                test_case  = "parameter_copy"
                version    = "1.0"
                edge_cases = @("missing_source")
            }
            labels = @("data-management","error-handling")
        }
    }
    $doc = "This example shows how to copy a parameter value..."
    $emb = @(0.12, 0.34, 0.56)
    $out = Convert-Example `
        -Id "copy-parameter" `
        -Document $doc `
        -Embedding $emb `
        -Example $example `
        -PluginKey "CopyParameter"
    # Returns a hashtable with .id and .ragDocument
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]   $Id,

        [Parameter(Mandatory = $true)]
        [string]   $Document,

        [Parameter(Mandatory = $true)]
        [double[]] $Embedding,

        [Parameter(Mandatory = $true)]
        [psobject] $Example,

        [Parameter(Mandatory = $true)]
        [string]   $PluginKey
    )

    # Create a timestamp for uniqueness
    $dynamicId = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

    # Build the document ID: pluginKey-example-timestamp-id
    $documentId = "$($PluginKey.ToLower())-example-$($dynamicId)-$($Id)".Replace("_","-")

    # Initialize metadata with fixed fields
    $metadata = @{
        section     = "examples"   # marks this as an example entry
        plugin_name = $PluginKey   # store plugin key for filtering
    }

    # Extract annotations and labels from the example context
    $annotations = $Example.context.annotations
    $labels      = $Example.context.labels

    # Add each annotation property to metadata
    foreach ($prop in $annotations.PSObject.Properties) {
        if ($prop.Name -eq "edge_cases") {
            # Add a flag for each edge case
            foreach ($edgeCase in $prop.Value) {
                $metadata["edge_case:$edgeCase"] = $true
            }
            continue
        }
        # Add other annotation properties directly
        $metadata[$prop.Name] = $prop.Value
    }

    # Add each label as a boolean flag
    foreach ($label in $labels) {
        $metadata["label:$label"] = $true
    }

    # Sort metadata keys alphabetically for consistent ordering
    $sortedMetadata = [ordered]@{}
    $metadata.GetEnumerator() |
        Sort-Object Name |
        ForEach-Object { $sortedMetadata[$_.Name] = $_.Value }

    # Wrap the single embedding vector in an array for RAG compatibility
    $nestedEmbeddings = ,$Embedding

    # Assemble the RAG document payload
    $ragDocument = @{
        ids        = @($documentId)     # array of document ids
        embeddings = $nestedEmbeddings  # array of embedding vectors
        metadatas  = @($sortedMetadata) # array of metadata hashtables
        documents  = @($Document)       # array of document text strings
    }

    # Return the id and the full RAG document structure
    return @{
        id          = $documentId
        ragDocument = $ragDocument
    }
}

function Convert-QuestionAndAnswer {
    <#
    .SYNOPSIS
    Build a RAG document object for a question-and-answer entry.

    .DESCRIPTION
    Convert-QuestionAndAnswer packages a Q&A text and its embedding vector
    into a format suitable for vector store ingestion. It generates a unique
    document ID based on the plugin key and current time, attaches metadata,
    and assembles the RAG payload.

    .PARAMETER Document
    The complete question and answer text block to index.

    .PARAMETER Embedding
    The numeric embedding vector corresponding to the Document.

    .PARAMETER PluginKey
    The slug or key of the plugin (e.g. "Assert"), used to namespace the ID
    and metadata.

    .OUTPUTS
    Hashtable with:
      - id          : Unique document identifier
      - ragDocument : RAG payload with ids, embeddings, metadatas, and documents

    .EXAMPLE
    $qa = "Question: What is the Assert plugin?`nAnswer: It verifies conditions."
    $emb = @(0.12, 0.34, 0.56)
    $out = Convert-QuestionAndAnswer -Document $qa -Embedding $emb -PluginKey "Assert"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]   $Document,

        [Parameter(Mandatory=$true)]
        [double[]] $Embedding,

        [Parameter(Mandatory=$true)]
        [string]   $PluginKey
    )

    # Create a timestamp to ensure document ID uniqueness
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()

    # Format the document ID: pluginKey-qa-timestamp
    $documentId = "{0}-qa-{1}" -f $PluginKey.ToLower(), $timestamp

    # Build metadata for the Q&A entry
    $metadata = @{
        section     = "questions_and_answers"  # identifies the RAG section
        plugin_name = $PluginKey               # plugin namespace for filtering
    }

    # Prepare the embedding array for the RAG payload
    $embeddingsArray = ,$Embedding

    # Assemble the RAG document structure
    $ragDocument = @{
        ids        = @($documentId)  # single-element array of document IDs
        embeddings = $embeddingsArray
        metadatas  = @($metadata)    # single-element array of metadata
        documents  = @($Document)    # single-element array of document text
    }

    # Return the complete RAG object with ID and payload
    return @{
        id          = $documentId
        ragDocument = $ragDocument
    }
}

function Get-Embedding {
    <#
    .SYNOPSIS
    Retrieve an embedding vector for a given text from an embedding API.

    .DESCRIPTION
    Sends a POST request to the specified embedding endpoint with the provided
    text and model, then returns the resulting embedding vector.

    .PARAMETER EmbeddingApiUri
    The full URI of the embedding API endpoint, for example:
    "https://api.openai.com/v1/embeddings".

    .PARAMETER EmbeddingModel
    The name of the embedding model to use, for example:
    "text-embedding-ada-002".

    .PARAMETER Headers
    A hashtable of HTTP headers required for authentication, e.g:
    @{ "Authorization" = "Bearer <token>" }.

    .PARAMETER TextContent
    The text string to embed.

    .OUTPUTS
    An array of doubles representing the embedding vector.

    .EXAMPLE
    $headers = @{ "Authorization" = "Bearer $env:OPENAI_API_KEY" }
    $vector  = Get-Embedding `
                  -EmbeddingApiUri "https://api.openai.com/v1/embeddings" `
                  -EmbeddingModel "text-embedding-ada-002" `
                  -Headers $headers `
                  -TextContent "Hello, world!"
    # Returns an array of floating-point values.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]   $EmbeddingApiUri,

        [Parameter(Mandatory = $true)]
        [string]   $EmbeddingModel,

        [Parameter(Mandatory = $true)]
        [hashtable]$Headers,

        [Parameter(Mandatory = $true)]
        [string]   $TextContent
    )

    # Prepare the JSON payload with the text and model
    $payload = @{
        input = $TextContent
        model = $EmbeddingModel
    }

    # Convert the payload to a compact JSON string
    $body = $payload | ConvertTo-Json -Depth 50 -Compress

    # Call the embedding API and capture the response
    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $EmbeddingApiUri `
        -Headers $Headers `
        -Body $body `
        -ContentType '"application/json; charset=utf-8"'

    # Return the embedding vector from the first data element
    return $response.data[0].embedding
}

function Get-Manifest {
    <#
    .SYNOPSIS
    Retrieves a plugin manifest as a raw JSON string from the G4 integration API.

    .PARAMETER HubUri
    The base URI of the hub (e.g. "http://hub.example.com").

    .PARAMETER PluginType
    The plugin type segment to insert into the URL.

    .PARAMETER PluginKey
    The plugin key segment to insert into the URL.

    .EXAMPLE
    Get-Manifest -HubUri "http://hub.example.com" -PluginType "Assert" -PluginKey "AlertExists"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HubUri,

        [Parameter(Mandatory = $true)]
        [string]$PluginType,

        [Parameter(Mandatory = $true)]
        [string]$PluginKey
    )

    # Build the full request URL, ensuring no duplicate slashes
    $base = $HubUri.TrimEnd('/')
    $uri  = "$base/api/v4/g4/integration/manifests/type/$PluginType/key/$PluginKey"

    try {
        # Perform GET and return the raw JSON string
        $response = Invoke-WebRequest `
            -Uri $uri `
            -Method Get `
            -UseBasicParsing `
            -ErrorAction Stop

        return $response.Content
    }
    catch {
        Throw "Failed to retrieve manifest from $uri. $_"
    }
}

function Import-EnvironmentVariablesFile {
    <#
    .SYNOPSIS
        Imports environment variables from an environment file and additional parameters into the current session.

    .DESCRIPTION
        This function reads an environment file (each line formatted as KEY=value) and splits each line on the first "=".
        In addition, it accepts an array of additional environment variable strings (AdditionalEnvironmentVariables) in key=value format.
        Both sets of key-value pairs are imported into the current session's environment.
        Any keys specified in SkipNames are skipped.

    .PARAMETER EnvironmentFilePath
        The full path to the environment file. Defaults to ".env" in the script's directory.

    .PARAMETER SkipNames
        An array of environment variable names that should not be imported from the file or the additional parameters.

    .PARAMETER AdditionalEnvironmentVariables
        An array of additional environment variable strings in key=value format.
        
    .EXAMPLE
        Import-EnvironmentVariablesFile -EnvironmentFilePath ".\config\environment.env" -SkipNames "PATH","JAVA_HOME" `
            -AdditionalEnvironmentVariables @("MY_VAR=Value1", "OTHER_VAR=Value2")
    #>
    [CmdletBinding()]
    param(
        [string]  $EnvironmentFilePath            = (Join-Path $PSScriptRoot ".env"),
        [string[]]$SkipNames                      = @(),
        [string[]]$AdditionalEnvironmentVariables = @()
    )

    Write-Verbose "Check if the environment file exists; if not, display a message and exit"
    if (-Not (Test-Path $EnvironmentFilePath)) {
        Write-Warning "The environment file was not found at path: $($EnvironmentFilePath)"
        return
    }

    Write-Verbose "Read the environment file line by line"
    $parametersCollection = (Get-Content $EnvironmentFilePath -Force -Encoding UTF8) + $AdditionalEnvironmentVariables
    $parametersCollection | ForEach-Object {
        Write-Verbose "Skip lines that are comments (starting with '#') or empty after trimming whitespace"
        if ($_.Trim().StartsWith("#") -or [string]::IsNullOrWhiteSpace($_)) {
            return
        }

        Write-Verbose "Split the line into two parts at the first '=' occurrence"
        $parts = $_.Split('=', 2)
        
        Write-Verbose "If the line does not contain exactly two parts, skip it"
        if ($parts.Length -ne 2) {
            return
        }
        
        Write-Verbose "Trim any leading or trailing whitespace from the key and value"
        $key   = $parts[0].Trim()
        $value = $parts[1].Trim()

        # Skip this key if it is in the skip list.
        if ($SkipNames -contains $key) {
            Write-Verbose "Skipping environment variable '$($key)' as it is in the skip list"
            return
        }
        
        Set-Item -Path "Env:$($key)" -Value $value
        Write-Verbose "Set environment variable '$($key)' with value '$($value)'"
    }
}

Import-EnvironmentVariablesFile

# Load the manifest JSON for the specified plugin from the hub API
$manifest = Get-Manifest `
    -HubUri $HubUri `
    -PluginType $PluginType `
    -PluginKey $PluginKey | ConvertFrom-Json
$manifest = Get-Content -Path "C:\Users\s_roe\OneDrive\Desktop\New folder\g4-plugins\src\G4.Plugins.Common\Actions.Manifests\NoAction.json" | ConvertFrom-Json

# Define base directories for ChromaDB and OpenWeb UI outputs
$ChromaDbOutputDirectory  = Join-Path $RootPath "dataset/chromadb-documents"
$OpenWebUiOutputDirectory = Join-Path $RootPath "dataset/g4-rag-documents"

# Create plugin-specific subfolders (lowercase key) under each base path
$chromaOutput = Join-Path $ChromaDbOutputDirectory $manifest.key.ToLower()
$webuiOutput  = Join-Path $OpenWebUiOutputDirectory $manifest.key.ToLower()

# Set the content type for JSON payloads
$contentType = "application/json; charset=utf-8"

# Join the array of description lines into a single string with newlines
$description = [string]::Join([System.Environment]::NewLine, $manifest.description)

# Extract the Q&A list and examples array from the manifest context
$qas      = $manifest.context.integration.rag.qa
$examples = $manifest.examples

# Prepare HTTP headers (including API key) for embedding requests
$headers = @{
    "Authorization" = "Bearer $OpenAiApiKey"
}

# Ensure the output directories exist (creates them if missing)
[System.IO.Directory]::CreateDirectory($chromaOutput) | Out-Null
[System.IO.Directory]::CreateDirectory($webuiOutput)  | Out-Null

# --------------------------------------------------
# PROCESS DESCRIPTION
# --------------------------------------------------

# Generate embedding vector for the plugin description text
$descriptionEmbedding = Get-Embedding `
    -EmbeddingApiUri $EmbeddingApiUri `
    -EmbeddingModel  $EmbeddingModel `
    -Headers         $headers `
    -TextContent     $description

# Convert the description text and its embedding into a RAG document hashtable
$ragEntry = Convert-Description `
    -Document  $description `
    -Embedding $descriptionEmbedding `
    -PluginKey $manifest.key

# Serialize the RAG document payload to a compact JSON string
$ragEntryBody = ConvertTo-Json `
    -InputObject $ragEntry.ragDocument `
    -Depth       50 `
    -Compress

# Write out the RAG JSON document for ChromaDB ingestion
Set-Content `
    -Value $ragEntryBody `
    -Path  (Join-Path $chromaOutput "$($ragEntry.id).json") `
    -Force

# Write out the raw description text for the OpenWeb UI
Set-Content `
    -Value $description `
    -Path  (Join-Path $webuiOutput "$($ragEntry.id).md") `
    -Force

# --------------------------------------------------
# PROCESS Q&A
# --------------------------------------------------

# Count total Q&A entries for progress calculation
$totalQas = $qas.Length

for ($i = 0; $i -lt $totalQas; $i++) {
    # Compute current index (1-based) and percentage complete
    $current         = $i + 1
    $percentComplete = [math]::Round(($current / $totalQas) * 100)

    # Display progress bar in the console
    Write-Progress `
        -Activity        "Embedding Q&A Pairs" `
        -Status          "Processing Q&A $($current) of $($totalQas)" `
        -PercentComplete $percentComplete

    # Extract the question and answer from the manifest object
    $question = $qas[$i].question
    $answer   = $qas[$i].answer

    # Combine question and answer into one text block
    $qaPair = [string]::Join([Environment]::NewLine, @("Question: $($question)", "Answer: $($answer)"))

    # Retrieve embedding vector for the combined Q&A text
    $qaEmbedding = Get-Embedding `
        -EmbeddingApiUri $EmbeddingApiUri `
        -EmbeddingModel  $EmbeddingModel `
        -Headers         $headers `
        -TextContent     $qaPair

    # Convert the Q&A pair into a RAG document structure
    $ragEntry = Convert-QuestionAndAnswer `
        -Document  $qaPair `
        -Embedding $qaEmbedding `
        -PluginKey $manifest.key

    # Serialize the RAG payload to a compact JSON string
    $ragEntryBody = ConvertTo-Json `
        -InputObject $ragEntry.ragDocument `
        -Depth       50 `
        -Compress

    # Write the JSON payload for ChromaDB ingestion
    $jsonPath = Join-Path $chromaOutput "$($ragEntry.id).json"
    Set-Content `
        -Value $ragEntryBody `
        -Path  $jsonPath `
        -Force

    # Write the raw Q&A Markdown for the OpenWeb UI
    $mdPath = Join-Path $webuiOutput "$($ragEntry.id).md"
    Set-Content `
        -Value $qaPair `
        -Path  $mdPath `
        -Force
}

# Clear the progress bar when done
Write-Progress -Activity "Embedding Q&A Pairs" -Completed

# --------------------------------------------------
# PROCESS EXAMPLES
# --------------------------------------------------

# Define the system prompt for converting examples into Markdown
$systemPrompt = @"
You are a documentation assistant that converts structured plugin rule examples into Markdown documents optimized for retrieval and AI-assisted automation generation.

### Input

You are given an input object with:

- `description`: an array of markdown-formatted strings
- `rule`: a structured object containing rule metadata and execution parameters. This may include:
  - `$type`, `pluginName`, `argument` (always present)
  - Optional: `onElement`, `onAttribute`, `locator`, `regularExpression`, `context`, `rules`, and other fields

### Output Format

You must generate a **Markdown document** with:

#### 1. Title and Description

- Extract the first non-empty line in `description` and use it as the `###` title
- Join the rest of the lines into a paragraph, skipping empty lines
- Keep markdown formatting

#### 2. Rule Summary (Bullet List)

- List **all fields** from `rule` in the format:
  ```
  - **<Field Name>**: <value>
  ```
  - Format the field name in **article case** (e.g., `onElement` > `On Element`, `pluginName` > `Plugin Name`) **except `$type field**.
- If a field's value is an object, convert it to compact JSON (`ConvertTo-Json -Compress` style).
- If a field is a **string expression** in the form: `{{$ --Condition:XYZ --key:value ...}}`, interpret it as follows:
  - Display a summarized entry:
    ```
    - **argument**: <short purpose>
    ```
  - Then break down the expression into a bullet list:
    ```
    - **parameters**:
      - **Condition**: XYZ — <explanation>
      - **key**: value — <explanation>
    ```
  - Follow the same phrasing rules as for **Rule Purpose** (short, factual, everyday language, optimized for retrieval).
- If the argument contains a **macro expression** like `{{`$MacroName --key:value ...}}`, do not break it down:
  - Display it as:
    ```
    - **argument**: macro... <short purpose>
    ```
  - Still provide the **short purpose** in the same style as other rule descriptions.
- For fields **known to be unused or ignored** based on the plugin and condition (e.g., `onElement` when `--Condition:AlertExists` is used), mark them clearly:
  ```
  - **onElement**: _(ignored by AlertExists condition)_
  ```

#### 3. JSON Code Block

Include a `#### Automation Rule (JSON)` section and output the full rule object as indented JSON in a fenced `json` block.

### Field Handling Rules

- Only use the fields that are actually present in the input `rule` object.
- Do not invent, infer, or add extra fields that are not in the original example.
- For each field, display it in the summary section as:
  - `- **<field>**: <value>`
- If a field contains an object or array, display it as a compact inline JSON string.
- If a field is known to be ignored by the current condition or plugin logic, mark it like this:
  - `- **onElement**: _(ignored by AlertExists condition)_`
- In addition to the rule fields, include a helpful line:
  - `- **Rule Purpose**: <short explanation of what the rule does>`
  - This should be a clear, simple sentence that describes the goal or behavior of the rule in everyday language (e.g.,  "Check that no alert is currently showing on the page.")
  - This field must always be the first in the bullets list
- Output **must** be UTF-8 no ascii or special chars

### Output Encoding Rule

**Your response must be plain UTF-8 safe text only.**  
- Do not use special characters outside the standard ASCII range.  
- Avoid all non-standard formatting characters such as:
  - Curly quotes (“ ” ‘ ’)
  - En/em dashes (– —)
  - Non-breaking spaces, ligatures, or typographic symbols  
- Only use standard straight quotes (`"`, `'`), hyphens (`-`), and regular spaces.  
- The output must be fully compatible with plain-text systems that only support standard UTF-8 characters.

### Example Input

```json
{
  "description": [
    "### Alert Existence Check",
    "",
    "This example shows how the Assert plugin verifies that a native browser alert is present.",
    "If a native alert is detected, the assert evaluates to `true`."
  ],
  "rule": {
    "`$type": "Action",
    "pluginName": "Assert",
    "argument": "{{$ --Condition:AlertExists}}"
  }
}
```

### Expected Output

```
### Alert Existence Check

This example shows how the Assert plugin verifies that a native browser alert is present.  
If a native alert is detected, the assert evaluates to `true`.

- **Type**: Action  
- **Plugin Name**: Assert  
- **Argument**: Check if a native alert is present  
  - **Parameters**:  
    - **Condition**: AlertExists - Detects whether a native browser alert is open

#### Automation Rule (JSON)

```json
{
  "$type": "Action",
  "pluginName": "Assert",
  "argument": "{{$ --Condition:AlertExists}}"
}
```
```
"@

# Process each example in the manifest
for ($i = 0; $i -lt $examples.Length; $i++) {
    # Get the current example
    $example = $examples[$i]

    # Calculate progress
    $current         = $i + 1
    $percentComplete = [math]::Round(($current / $examples.Length) * 100)

    # Show progress bar
    Write-Progress `
        -Activity        "Processing Examples" `
        -Status          "Example $($current) of $($examples.Length)" `
        -PercentComplete $percentComplete

    # Build the JSON payload for the AI request
    $contentJson = @{
        description = $example.description
        rule        = $example.rule
    } | ConvertTo-Json -Depth 50 -Compress

    # Assemble the chat messages for the AI model
    $messages = @(
        @{ role = "system"; content = $systemPrompt }
        @{ role = "user";   content = $contentJson }
    )

    # Create the request body with model settings
    $body = @{
        model       = $OpenAiModel
        messages    = $messages
        temperature = 0.1
        max_tokens  = $MaxTokens
    } | ConvertTo-Json -Depth 50 -Compress

    # Number of attempts for retry logic
    $numberOfRetries = 3

    # Try the AI request and embedding, with retries on failure
    for ($attempt = 1; $attempt -le $numberOfRetries; $attempt++) {
        try {
            # Indicate sending the document to the AI for Markdown conversion
            Write-Progress `
                -Activity "Processing Examples" `
                -Status   "Example $($current) of $($examples.Length) - Generating Markdown" `
                -PercentComplete $percentComplete

            # Call the AI API to transform the structured example into Markdown
            $response = Invoke-RestMethod `
                -Uri         $OpenAiApiUri `
                -Method      Post `
                -Headers     $headers `
                -Body        $body `
                -ContentType $contentType

            # Extract the generated Markdown content
            $generatedText = $response.choices[0].message.content

            # Indicate embedding of the generated text
            Write-Progress `
                -Activity "Processing Examples" `
                -Status   "Example $($current) of $($examples.Length) - Embedding Generated Text" `
                -PercentComplete $percentComplete

            # Get embedding for the generated Markdown
            $generatedEmb = Get-Embedding `
                -EmbeddingApiUri $EmbeddingApiUri `
                -EmbeddingModel  $EmbeddingModel `
                -Headers         $headers `
                -TextContent     $generatedText

            # Convert the example into a RAG document
            $exampleRag = Convert-Example `
                -Id        $example.context.annotations.test_case `
                -Document  $generatedText `
                -Embedding $generatedEmb `
                -Example   $example `
                -PluginKey $manifest.key

            # Serialize the RAG payload to JSON
            $ragEntryBody = ConvertTo-Json `
                -InputObject $exampleRag.ragDocument `
                -Depth       50 `
                -Compress

            # Exit retry loop on success
            break
        }
        catch {
            # Warn on failure and retry after a short pause
            Write-Warning "Attempt $($attempt) of $($numberOfRetries) failed: $($_)"
            if ($attempt -lt $numberOfRetries) {
                Start-Sleep -Seconds 2
            }
            else {
                throw "All $($numberOfRetries) attempts failed."
            }
        }
    }

    # Write the RAG JSON document for ChromaDB ingestion
    $jsonPath = Join-Path $chromaOutput "$($exampleRag.id).json"
    Set-Content -Value $ragEntryBody -Path $jsonPath -Force

    # Write the generated Markdown for the OpenWeb UI
    $mdPath = Join-Path $webuiOutput "$($exampleRag.id).md"
    Set-Content -Value $generatedText -Path $mdPath -Force
}

# Clear the progress bar once all examples are processed
Write-Progress -Activity "Processing Examples" -Completed
