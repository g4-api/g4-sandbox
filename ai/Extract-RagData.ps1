<#
.SYNOPSIS
    Processes plugin manifests to create RAG entries with embeddings.

.DESCRIPTION
    This script communicates with the hub API to process plugin repositories and extract plugin manifests.
    It then calls OpenAI's API to extract key information from each manifest and generate embeddings,
    resulting in the creation of a RAG (Retrieval-Augmented Generation) entry. Each RAG entry includes metadata,
    usage examples, the full text of the manifest extraction, and the generated embedding. The final output for
    each plugin is saved as a JSON file in the specified output directory.

.PARAMETER EmbeddingApiUri
    The URI endpoint for the embedding API. Defaults to "https://api.openai.com/v1/embeddings".

.PARAMETER EmbeddingModel
    The identifier for the embedding model to be used by the API. Defaults to "text-embedding-ada-002".

.PARAMETER ErrorsDirectory
    The directory path where error JSON files (failed RAG entries) will be saved. Defaults to a subdirectory
    named "rag-entries-errors" within the script directory.

.PARAMETER HubUri
    The base URI of the hub API endpoint. This is used to send repository data to the hub API.

.PARAMETER IncludePlugins
    An array of plugin identifiers (or names) to specifically include in the processing. If provided, only these plugins will be processed.

.PARAMETER IncludePluginsTypes
    An array of strings indicating which plugin types to include (e.g., "Action", "Macro").

.PARAMETER MaxTokens
    The maximum number of tokens to use in the OpenAI API request. Defaults to 6000.

.PARAMETER OpenAiApiKey
    A valid OpenAI API key required for authentication when calling the OpenAI API endpoints.

.PARAMETER OpenAiApiUri
    The URI endpoint for the OpenAI chat API. Defaults to "https://api.openai.com/v1/chat/completions".

.PARAMETER OpenAiModel
    A string representing the AI model used for processing, if applicable. Defaults to "gpt-4o-mini".

.PARAMETER OutputDirectory
    The directory path where the output JSON files (RAG entries) will be saved. Defaults to a subdirectory
    named "rag-entries" within the script directory.

.PARAMETER Repositories
    An array of repository objects (PSCustomObject) containing information about plugin repositories.
    Each repository object should include all necessary details to be processed.

.EXAMPLE
    .\Process-PluginManifests.ps1 -HubUri "https://example.com" -OpenAiApiKey "your-api-key" `
        -OutputDirectory "C:\Output" -Repositories $repoArray

.NOTES
    - The script expects a valid OpenAI API key.
    - The Repositories parameter should contain properly formed repository objects.
    - Each RAG entry contains plugin metadata, usage examples, the full text of the manifest extraction, and the generated embedding.
#>
param(
    [CmdletBinding()]
    [Parameter(Mandatory = $false)]
    [string]$EmbeddingApiUri = "https://api.openai.com/v1/embeddings",
    
    [Parameter(Mandatory = $false)]
    [string]$EmbeddingModel = "text-embedding-ada-002",
    
    [Parameter(Mandatory = $false)]
    [string]$ErrorsDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "rag-entries-errors"),
    
    [Parameter(Mandatory = $true)]
    [string]$HubUri,

    [Parameter(Mandatory = $false)]
    [string[]]$IncludePlugins = @(),
    
    [Parameter(Mandatory = $false)]
    [string[]]$IncludePluginsTypes = @("Action", "Macro"),
    
    [Parameter(Mandatory = $false)]
    [int]$MaxTokens = 6000,
    
    [Parameter(Mandatory = $true)]
    [string]$OpenAiApiKey,
    
    [Parameter(Mandatory = $false)]
    [string]$OpenAiApiUri = "https://api.openai.com/v1/chat/completions",
    
    [Parameter(Mandatory = $false)]
    [string]$OpenAiModel = "gpt-4o-mini",
    
    [Parameter(Mandatory = $false)]
    [string]$OutputDirectory = (Join-Path -Path $PSScriptRoot -ChildPath "rag-entries"),
    
    [Parameter(Mandatory = $false)]
    [PSCustomObject[]]$Repositories = @()
)

# Constants
$headers = @{
    "Authorization" = "Bearer $OpenAiApiKey"
}

$contentType = "application/json; charset=utf-8"

$systemPrompt = @"
Extract the most important and context-rich parts of the following manifest and break them down into two sections: metadata and usage examples. Your extraction must include the following elements from the manifest:

- **Plugin Key & Aliases**
- **Summary & Description**
- **Key Parameters & Key Properties** – In the manifest, these are under the fields "parameters" and "properties" respectively.
- **Output Parameters** – In the manifest, this is under the field "outputParameters".
- **Usage Examples** – Include at least one usage example in its original JSON format from the manifest.

For the metadata section, break it down into the following fields:
- **plugin_key:** The primary key or identifier for the plugin.
- **aliases:** An array of alternative names for the plugin.
- **summary:** A brief overview of what the plugin does.
- **description:** A detailed explanation of the plugin's purpose and functionality. (If the description is an array, convert it into a single string by concatenating the elements with newline characters.)
- **key_parameters:** An object containing the key parameters exactly as they appear in the manifest (from the "parameters" field). For any "description" fields that are arrays, convert them into single strings using newline characters.
- **key_properties:** An object containing the key properties exactly as they appear in the manifest (from the "properties" field). For any "description" fields that are arrays, convert them into single strings using newline characters.
- **output_parameters:** An object containing the output parameters exactly as they appear in the manifest (from the "outputParameters" field). Convert any "description" arrays into a single string using newline characters.
- **use_cases:** An array of typical use cases for the plugin. If the manifest does not explicitly list use cases, deduce them based on the plugin's summary, description, and parameters.
- **version:** The version of the plugin; if not provided in the manifest, use "1.0".
- **$$type:** The value of the "$type" field found within the "context" field in the manifest; if not found, default to "Action".

Output the result as a JSON object with the following keys (without any code block formatting):
  - "id": containing the plugin's key,
  - "resource_id": containing the same value as the plugin's key,
  - "metadata": containing an object with the fields: plugin_key, aliases, summary, description, key_parameters, key_properties, output_parameters, use_cases, version, and $type,
  - "examples": containing an array of one or more usage examples in their original JSON format (if any "description" fields in the examples are arrays, convert them into single strings using newline characters),
  - "text": an empty string,
  - "embedding": an empty array.

Ensure that all description fields (in metadata and examples) that are arrays are concatenated into single strings using newline characters. The output must be clear, concise, and generic enough to apply to any plugin manifest, and the examples must be explicitly included in JSON format.
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
        Generates an embedding for a plugin's document text and appends it to the original JSON.

    .DESCRIPTION
        This function processes a JSON string (RagEntry) representing a plugin manifest by extracting the summary from
        its metadata and appending descriptions from all its examples to form a document text. It then builds a request
        body and calls an external embedding API to generate an embedding for the document text. Finally, it updates the
        original JSON object with both the document text and the generated embedding, returning the updated JSON as a
        compressed string.

    .PARAMETER ContentType
        The MIME type for the API request (e.g., "application/json; charset=utf-8").

    .PARAMETER EmbeddingApiUri
        The URI endpoint for the embedding API.

    .PARAMETER EmbeddingModel
        The identifier for the embedding model to be used by the API.

    .PARAMETER Headers
        A hashtable of HTTP headers to include in the API request, such as authorization tokens.

    .PARAMETER RagEntry
        A JSON string representing the plugin manifest. It must include a 'metadata' property with a 'summary' field and an
        'examples' array containing example objects with 'description' fields.

    .EXAMPLE
        $updatedJson = Set-Embedding `
                        -ContentType "application/json; charset=utf-8" `
                        -EmbeddingApiUri "https://api.example.com/embedding" `
                        -EmbeddingModel "model-v1" `
                        -Headers @{ Authorization = "Bearer token" } `
                        -RagEntry $pluginJson
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
        [string]$RagEntry
    )

    Write-Verbose "Convert the JSON string into a PowerShell object"
    $jsonContent = $RagEntry | ConvertFrom-Json

    Write-Verbose "Initialize the document text with the summary from metadata"
    $documentText = $jsonContent.metadata.summary

    Write-Verbose "Iterate over each example in the JSON and append all description texts to the document"
    foreach ($example in $jsonContent.examples) {
        $documentText += " " + ($example.description -join " ")
    }

    Write-Verbose "Create the body for the API request including the document text and the model name"
    $body = @{
        input = $documentText
        model = $EmbeddingModel
    } | ConvertTo-Json -Depth 50 -Compress

    Write-Verbose "Calling Embedding API for plugin: $($jsonContent.id)..."
    $response = Invoke-RestMethod `
        -Method      Post `
        -Uri         $EmbeddingApiUri `
        -Headers     $Headers `
        -Body        $body `
        -ContentType $ContentType

    Write-Verbose "Append the original text and the generated embedding to the JSON object"
    $jsonContent.text      = $documentText
    $jsonContent.embedding = $response.data[0].embedding

    Write-Verbose "Convert the updated object back to a JSON string with a specified depth and compression"
    return (ConvertTo-Json -InputObject $jsonContent -Depth 50 -Compress)
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

Write-Verbose "Converting repositories to JSON format..."
$body = ConvertTo-Json -InputObject $Repositories -Depth 10 -Compress

Write-Verbose "Calling the cache API endpoint..."
$response = Invoke-RestMethod `
    -Uri         "$($HubUri)/api/v4/g4/integration/cache" `
    -Method      Post `
    -Headers     $headers `
    -Body        $body `
    -ContentType "application/json; charset=utf-8"
   
Write-Verbose "Filtering response for included plugin types..."
$plugins = @()

foreach ($domain in $response.PSObject.Properties) {
    if ($IncludePluginsTypes -notcontains $domain.Name) {
        continue
    }

    Write-Verbose "Loop through each plugin within the domain..."
    foreach ($plugin in $domain.Value.PSObject.Properties) {
        Write-Verbose "Ensure that the key matches the property name"
        $key = $plugin.Value.manifest.key
        if ($key -ne $plugin.Name) {
            continue
        }

        Write-Verbose "Construct a simplified object with the plugin key and manifest"
        $pluginObject = @{
            Key      = $key
            Manifest = $plugin.Value.manifest
        }

        Write-Verbose "Add the plugin object to the plugins array"
        $plugins += $pluginObject
    }
}

Write-Verbose "Process each plugin manifest by sending it to the OpenAI API for extraction..."
$total  = $plugins.Count
$i      = 0

foreach ($plugin in $plugins) {
    $i++
    Write-Progress `
        -Activity        "Processing Plugins" `
        -Status          "Processing Plugin $i of $total ($($plugin.Key))" `
        -PercentComplete (($i / $total) * 100)

    # Check it the array is non-empty and does not contain the specific string (and true otherwise)
    if ($IncludePlugins.Count -gt 0 -and ($IncludePlugins -notcontains $plugin.Key)) {
        continue
    }

    Write-Verbose "Create the messages array for the chat API with the system prompt and user message"
    $manifestText = ConvertTo-Json -InputObject $plugin.Manifest -Depth 50
    $messages = @(
        @{ role = "system"; content = $systemPrompt },
        @{ role = "user"; content = $manifestText }
    )
    
    Write-Verbose "Build the request body for the OpenAI chat API"
    $body = @{
        model       = $OpenAiModel
        messages    = $messages
        temperature = 0.1
        max_tokens  = $MaxTokens
    } | ConvertTo-Json -Depth 50 -Compress

    Write-Verbose "Define the API endpoint URI and headers"
    $uri = $OpenAiApiUri
    $headers = @{
        "Authorization" = "Bearer $OpenAiApiKey"
    }

    try {
        Write-Verbose "Calling OpenAI API for plugin: $($plugin.Key)..."
        $response = Invoke-RestMethod `
            -Uri         $uri `
            -Method      Post `
            -Headers     $headers `
            -Body        $body `
            -ContentType $contentType

        Write-Verbose "Extract the resulting message content from the API response"
        $content = $response.choices[0].message.content

        Write-Progress `
            -Activity        "Processing Plugins" `
            -Status          "Processing Plugin $i of $total ($($plugin.Key)) Generating Embedding" `
            -PercentComplete (($i / $total) * 100)
        $ragEntry = Set-Embedding `
            -ContentType     $contentType `
            -EmbeddingApiUri $EmbeddingApiUri `
            -EmbeddingModel  $EmbeddingModel `
            -Headers         $headers `
            -RagEntry        $content

        Write-Verbose "Generating file name using kebab-case conversion of the plugin key"
        $ragFileName = "$(Convert-PascalToKebab -InputString $plugin.Key).json"
        
        Write-Verbose "Constructing full output file path by combining the output directory and file name"
        $ragFilePath = Join-Path -Path $OutputDirectory -ChildPath $ragFileName

        Write-Verbose "Saving RAG entry to file: $ragFilePath"
        Set-Content -Path $ragFilePath -Value $ragEntry -Force
    }
    catch {
        Write-Verbose "An error occurred while processing plugin: $($plugin.Key)"
        Write-Error "Exception Message: $($_.Exception.Message)"

        Write-Verbose "Constructing error file path using the errors directory and file name"
        $errorFilePath = Join-Path -Path $ErrorsDirectory -ChildPath $ragFileName
        
        Write-Verbose "Saving failed request to file: $errorFilePath"
        Set-Content -Path $errorFilePath -Value $body -Force
    }
}

# Clear the progress bar when done
Write-Progress -Activity "Processing Plugins" -Completed