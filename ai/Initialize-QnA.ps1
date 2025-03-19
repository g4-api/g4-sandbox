param(
    [CmdletBinding()]
    [Parameter(Mandatory = $false)]
    [string]$EmbeddingApiUri = "https://api.openai.com/v1/embeddings",
    
    [Parameter(Mandatory = $false)]
    [string]$EmbeddingModel = "text-embedding-ada-002",
    
    [Parameter(Mandatory = $false)]
    [string]$ErrorsDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "rag-entries-qna-errors"),

    [Parameter(Mandatory = $false)]
    [string[]]$IncludePlugins = @(),

    [Parameter(Mandatory = $false)]
    [string]$InputDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "rag-entries"),
    
    [Parameter(Mandatory = $false)]
    [int]$MaxTokens = 6000,
    
    [Parameter(Mandatory = $true)]
    [string]$OpenAiApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$OpenAiApiUri = "https://api.openai.com/v1/chat/completions",
    
    [Parameter(Mandatory = $false)]
    [string]$OpenAiModel = "gpt-4o-mini",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "rag-entries-qna"),
    
    [Parameter(Mandatory = $false)]
    [PSCustomObject[]]$Repositories = @()
)

# Constants
$headers = @{
    "Authorization" = "Bearer $OpenAiApiKey"
}

$contentType = "application/json; charset=utf-8"

$embeddingPrompt = @"
Transform the following JSON QnA output into a coherent Markdown document suitable for embedding. The Markdown should be well-structured and easy to read, preserving the question-and-answer pairs. Each pair should be clearly separated, with the question in bold or as a heading and the answer in regular text. If the answer contains JSON code examples wrapped in triple backticks (with a language tag, e.g., ```json), retain these code blocks as-is. The final Markdown document should include a brief header with the plugin name (extracted from the "id" field without the "QnA" suffix) and then list all the QnA pairs. Do not include any extra introductory or concluding text outside the Markdown structure.

Example format:

```markdown
# Assert Plugin QnA

**Question 1:** How can I assert that the text of an element identified by the CSS selector '#greeting' matches the regular expression '^Hello.*'?

**Answer:** You can use the following rule to perform this assertion:
```json
{
  "argument": "{{$ --Condition:ElementText --Operator:Match --Expected:^Hello.*}}",
  "locator": "CssSelector",
  "onElement": "#greeting",
  "pluginName": "Assert"
}
```

... (and so on for each QA pair) ...


Below is the JSON QnA output to be transformed:

```json
{{RAG_ENTRY}}
```
"@

$embeddingSystemPrompt = @"
You are a transformation engine.
Your task is to transform a JSON QnA output into a coherent Markdown document suitable for embedding.
The Markdown should be well-structured and easy to read, preserving each question-and-answer pair.
Format each pair with the question in bold (or as a heading) and the answer in regular text.
Do not number the questions; simply present them as separate QnA pairs.
If the answer contains JSON code examples wrapped in triple backticks with a language tag (e.g., ```json), retain these code blocks as-is.
The final Markdown document should begin with a brief header that includes the plugin name (extracted from the 'id' field without the 'QnA' suffix), followed by all the QnA pairs.
Do not wrap the entire response in any markdown code fences (such as ```markdown).
Do not include any extra introductory or concluding text outside the Markdown structure.
"@

$systemPrompt = @"
You are provided with a plugin manifest that details a plugin's summary, description, key parameters, key properties, use cases, and example usages. The original manifest contains the fields "id" and "resource_id". Your task is to generate a series of question-and-answer pairs that test and illustrate the plugin’s functionality. The final output must be a structured JSON object that meets these requirements:

1. **Identifiers with Suffix:**  
   - Include an "id" field whose value is the original id with "QnA" appended (e.g., if the original id is "Assert", output `"id": "AssertQnA"`).  
   - Include a "resource_id" field whose value is the original resource_id with "QnA" appended (e.g., `"resource_id": "AssertQnA"`).

2. **QA Pairs Generation:**  
   - Generate a series of question-and-answer pairs that reference and cover the examples provided in the manifest.  
   - Also create new, realistic examples that illustrate various usage scenarios. When creating these examples, incorporate different locator strategies as follows:
     - For general plugins, include at least one example using each of the following locators: **Id, CssSelector,** and **Xpath**.
     - For Windows Native plugins, use only **Xpath**.
     - For Mobile Native plugins, choose three common locator strategies from the following list: **MobileElementResourceId, MobileElementName, MobileElementClassName, MobileElementAccessibilityId, IosPredicateString, IosClassChain, IosAutomation, AndroidViewMatcher, AndroidUiAutomator,** and **AndroidDataMatcher**.
   - Additionally, include at least one QA pair that addresses an edge case (e.g., what happens if a mandatory parameter is missing or an invalid locator is used).

3. **Parameter and Field Usage:**  
   - Include questions addressing how parameters (such as Timeout, Polling, and Condition) affect the plugin’s behavior.
   - Include questions that highlight how key properties (e.g., Argument, Locator, OnElement, OnAttribute) are used in constructing an automation flow.

4. **Structured Output Format (Plain Text JSON):**  
   - The final output must be a JSON object with exactly three keys:
     - `"id"`: the modified identifier (original value with "QnA" appended),
     - `"resource_id"`: the modified resource identifier (original value with "QnA" appended),
     - `"qa_pairs"`: an array of objects, each having two keys: `"question"` and `"answer"`.
   - Within each "answer" field, if you include any JSON examples or code snippets, wrap the JSON content in triple backticks with the appropriate language identifier (for example, ```json).
   - The overall output must not be wrapped in any code block formatting—only the JSON inside the "answer" fields should be in code blocks.

Do not include any introductory or concluding text; output only the JSON object as plain text.

Use the manifest provided below to generate the QA pairs:

``````json
{{RAG_ENTRY}}
``````
"@

function Convert-PascalToKebab {
    <#
    .SYNOPSIS
        Converts a PascalCase string to kebab-case.

    .DESCRIPTION
        This function converts a string from PascalCase format to kebab-case format.
        It uses a regular expression with positive lookbehind and positive lookahead to
        identify positions where a hyphen should be inserted (i.e., between a lowercase letter or digit and an uppercase letter).
        The resulting string is then converted to lower-case.

    .PARAMETER InputString
        The input string in PascalCase that will be converted to kebab-case.

    .EXAMPLE
        PS C:\> Convert-PascalToKebab -InputString "PascalCaseExample"
        Output: "pascal-case-example"

    .NOTES
        This function leverages .NET's System.Text.RegularExpressions.Regex class for regex replacement.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString
    )
    
    # Define a regex pattern using positive lookbehind and positive lookahead:
    # (?<=[a-z0-9]) asserts that the character immediately before the match is a lowercase letter or a digit.
    # (?=[A-Z]) asserts that the character immediately after the match is an uppercase letter.
    # This effectively finds the position between a lowercase/digit and an uppercase letter.
    $pattern = '(?<=[a-z0-9])(?=[A-Z])'
    
    # Use the .NET Regex.Replace method to insert a hyphen ('-') at each position where the pattern matches.
    $result = [System.Text.RegularExpressions.Regex]::Replace($InputString, $pattern, '-')
    
    # Convert the final result to lower-case to achieve the standard kebab-case format.
    return $result.ToLower()
}

function Set-Embedding {
    <#
    .SYNOPSIS
        Processes a RAG entry by calling OpenAI Chat and Embedding APIs to generate an embedding.

    .DESCRIPTION
        This function takes a JSON string representing a RAG (Retrieval-Augmented Generation) entry, converts it into a PowerShell object, and then performs the following steps:
          1. Creates a messages array with a system prompt and a user prompt (with the RAG entry embedded).
          2. Builds a request body and calls the OpenAI Chat API.
          3. Extracts the resulting message content from the API response.
          4. Constructs a new request body using the extracted text and calls the Embedding API.
          5. Appends both the original text and the generated embedding to the original JSON object.
          6. Returns the updated object as a JSON string.

    .PARAMETER ContentType
        The content type for the HTTP requests (typically "application/json").

    .PARAMETER EmbeddingApiUri
        The URI endpoint for the embedding API.

    .PARAMETER EmbeddingModel
        The model identifier for the embedding API (e.g., "text-embedding-ada-002").

    .PARAMETER Headers
        A hashtable of HTTP headers to be included in the API requests.

    .PARAMETER MaxTokens
        The maximum number of tokens to use in the OpenAI Chat API request.

    .PARAMETER OpenAiApiKey
        A valid OpenAI API key for authentication with the OpenAI APIs.

    .PARAMETER OpenAiApiUri
        The URI endpoint for the OpenAI Chat API.

    .PARAMETER OpenAiModel
        The model identifier for the OpenAI Chat API (e.g., "gpt-4o-mini").

    .PARAMETER RagEntry
        A JSON string representing the RAG entry containing plugin details.

    .EXAMPLE
        $updatedJson = Set-Embedding -ContentType "application/json" `
            -EmbeddingApiUri "https://api.openai.com/v1/embeddings" `
            -EmbeddingModel "text-embedding-ada-002" `
            -Headers $headers `
            -MaxTokens 6000 `
            -OpenAiApiKey "your-api-key" `
            -OpenAiApiUri "https://api.openai.com/v1/chat/completions" `
            -OpenAiModel "gpt-4o-mini" `
            -RagEntry $ragEntryJson
        Write-Output $updatedJson

    .NOTES
        Ensure that the variables $embeddingSystemPrompt and $embeddingPrompt are defined in your script or environment.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ContentType,

        [Parameter(Mandatory)]
        [string]$EmbeddingApiUri,

        [Parameter(Mandatory)]
        [string]$EmbeddingModel,

        [Parameter(Mandatory)]
        [hashtable]$Headers,

        [Parameter(Mandatory)]
        [int]$MaxTokens,

        [Parameter(Mandatory)]
        [string]$OpenAiApiKey,
    
        [Parameter(Mandatory)]
        [string]$OpenAiApiUri,

        [Parameter(Mandatory)]
        [string]$OpenAiModel,

        [Parameter(Mandatory)]
        [string]$RagEntry
    )

    Write-Verbose "Converting the RAG entry JSON string into a PowerShell object"
    [PSObject]$jsonContent = ConvertFrom-Json $RagEntry

    Write-Verbose "Creating messages array for the Chat API using system and user prompts"
    $messages = @(
        @{ role = "system"; content = $embeddingSystemPrompt },
        @{ role = "user"; content = $embeddingPrompt.Replace("{{RAG_ENTRY}}", $RagEntry) }
    )
    
    Write-Verbose "Building request body for the OpenAI Chat API"
    $body = @{
        model       = $OpenAiModel
        messages    = $messages
        temperature = 0.1
        max_tokens  = $MaxTokens
    } | ConvertTo-Json -Depth 50 -Compress

    Write-Verbose "Calling OpenAI Chat API for plugin: $($jsonContent.id)..."
    $response = Invoke-RestMethod `
        -Uri         $OpenAiApiUri `
        -Method      Post `
        -Headers     $Headers `
        -Body        $body `
        -ContentType $ContentType

    Write-Verbose "Extracting the generated message content from the Chat API response"
    $documentText = $response.choices[0].message.content

    Write-Verbose "Building request body for the Embedding API using the extracted text"
    $body = @{
        input = $documentText
        model = $EmbeddingModel
    } | ConvertTo-Json -Depth 50 -Compress

    Write-Verbose "Calling Embedding API for plugin: $($jsonContent.id)..."
    $response = Invoke-RestMethod -Method Post -Uri $EmbeddingApiUri -Headers $Headers -Body $body -ContentType $ContentType

    Write-Verbose "Appending the document text and generated embedding to the original JSON object"
    Add-Member -InputObject $jsonContent -MemberType NoteProperty -Name "text"      -Value $documentText
    Add-Member -InputObject $jsonContent -MemberType NoteProperty -Name "embedding" -Value $response.data[0].embedding

    Write-Verbose "Converting the updated object back to a JSON string"
    return (ConvertTo-Json -InputObject $jsonContent -Depth 50 -Compress)
}

Write-Verbose "Check if the input directory exists; if not, exit"
if (-Not (Test-Path -Path $InputDirectory)) {
    exit 0
}

Write-Verbose "Check if the output directory exists; if not, create it"
if (-Not (Test-Path -Path $OutputDirectory)) {
    Write-Verbose "Output directory does not exist. Creating directory: $OutputDirectory"
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

Write-Verbose "Check if the errors directory exists; if not, create it"
if (-Not (Test-Path -Path $ErrorsDirectory)) {
    Write-Verbose "Errors directory does not exist. Creating directory: $ErrorsDirectory"
    New-Item -ItemType Directory -Path $ErrorsDirectory -Force | Out-Null
}

Write-Verbose "Loading RAG entry files from InputDirectory: $InputDirectory"
$ragEntries = @(Get-ChildItem -Path "$InputDirectory" -File -Force -Recurse | ForEach-Object { Get-Content $_.FullName -Raw })

Write-Verbose "Total RAG entries found: $($ragEntries.Count)"
$total  = $ragEntries.Count
$i      = 0

foreach ($ragEntry in $ragEntries) {
    $i++
    $jsonData           = ConvertFrom-Json $ragEntry
    $jsonData.embedding = $null
    $jsonData.text      = $null

    Write-Progress `
        -Activity        "Processing Plugins" `
        -Status          "Processing Plugin $i of $total ($($jsonData.id))" `
        -PercentComplete (($i / $total) * 100)

    # If the IncludePlugins array is non-empty and does not contain the current plugin id, skip this entry.
    if ($IncludePlugins.Count -gt 0 -and ($IncludePlugins -notcontains $jsonData.id)) {
        Write-Verbose "Skipping plugin '$($jsonData.id)' because it is not listed in IncludePlugins."
        continue
    }

    Write-Verbose "Starting processing for plugin: $($jsonData.id)"
    $ragEntryContent = ConvertTo-Json -InputObject $jsonData -Depth 10 -Compress

    Write-Verbose "Building messages array for OpenAI Chat API for plugin: $($jsonData.id)"
    $messages = @(
        @{ role = "system"; content = "You are an expert in generating question-answer pairs for plugin manifests." },
        @{ role = "user"; content = $systemPrompt.Replace("{{RAG_ENTRY}}", $ragEntryContent) }
    )
    
    Write-Verbose "Constructing request body for the OpenAI Chat API for plugin: $($jsonData.id)"
    $body = @{
        model       = $OpenAiModel
        messages    = $messages
        temperature = 0.1
        max_tokens  = $MaxTokens
    } | ConvertTo-Json -Depth 50 -Compress

    try {
        Write-Verbose "Sending request to OpenAI Chat API for plugin: $($jsonData.id)"
        $response = Invoke-RestMethod `
            -Uri         $OpenAiApiUri `
            -Method      Post `
            -Headers     $headers `
            -Body        $body `
            -ContentType $contentType

        Write-Verbose "Extracting generated message content from the Chat API response for plugin: $($jsonData.id)"
        $content = $response.choices[0].message.content

        Write-Progress `
            -Activity        "Processing Plugins" `
            -Status          "Plugin $i of $total ($($jsonData.id)): Generating Embedding" `
            -PercentComplete (($i / $total) * 100)

        Write-Verbose "Calling Set-Embedding function to generate embedding for plugin: $($jsonData.id)"
        $ragEntry = Set-Embedding `
            -ContentType     $contentType `
            -EmbeddingApiUri $EmbeddingApiUri `
            -EmbeddingModel  $EmbeddingModel `
            -Headers         $headers `
            -MaxTokens       $MaxTokens `
            -OpenAiApiKey    $OpenAiApiKey `
            -OpenAiApiUri    $OpenAiApiUri `
            -OpenAiModel     $OpenAiModel `
            -RagEntry        $content

        Write-Verbose "Converting plugin id '$($jsonData.id)' to kebab-case for output filename"
        $ragFileName = "$(Convert-PascalToKebab -InputString $jsonData.id)-qna.json"
        
        Write-Verbose "Constructing full output file path: '$ragFileName' in directory: $OutputDirectory"
        $ragFilePath = Join-Path -Path $OutputDirectory -ChildPath $ragFileName

        Write-Verbose "Saving RAG entry for plugin '$($jsonData.id)' to file: $ragFilePath"
        Set-Content -Path $ragFilePath -Value $ragEntry -Force
    }
    catch {
        Write-Verbose "An error occurred while processing plugin '$($jsonData.id)': $($_.Exception.Message)"
        Write-Error "Exception Message: $($_.Exception.Message)"

        Write-Verbose "Constructing error file path for plugin '$($jsonData.id)'"
        $errorFilePath = Join-Path -Path $ErrorsDirectory -ChildPath $ragFileName
        
        Write-Verbose "Saving error details (request body) to file: $errorFilePath"
        Set-Content -Path $errorFilePath -Value $body -Force
    }
}
