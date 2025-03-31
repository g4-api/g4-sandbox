$KnowledgeIds      = @("ee4c8479-d9f1-422e-9cf2-efa70a0dc121", "208890fe-32cb-42c9-8be0-3653f660138f")
$ModelName         = "Test Model"
$BaseModel         = "deepseek-r1:latest"
$Description       = "Testing"
$SystemPrompt      = ""
$PromptSuggestions = @()
$OpenWebUiApiKey   = "sk-51097dce2441440dafb5de66cf293237"
$OpenWebUiUri      = "http://localhost:3000"
$ContextLength     = -1

function Get-Knowledge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KnowledgeId,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Loading System.Net.Http assembly..."
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Creating HttpClient instance for GET request..."
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Setting default request headers..."
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Construct the URL for the GET request (retrieves all knowledge objects)"
        $url = "$OpenWebUiUri/api/v1/knowledge/$KnowledgeId"
        Write-Verbose "Constructed GET URL: $url"

        Write-Verbose "Sending GET request to retrieve all knowledge entries..."
        $response = $client.GetAsync($url).Result

        if(!$response.IsSuccessStatusCode) {
            Write-Error "GET request failed with status code $($response.StatusCode): $($response.ReasonPhrase)"
            return
        }

        Write-Verbose "..."
        return $response.Content.ReadAsStringAsync().Result | ConvertFrom-Json
    }
    catch {
        Write-Error "An error occurred during initialization: $_"
    }
    finally {
        Write-Verbose "Disposing HttpClient instance used for GET request..."
        $client.Dispose()
    }
}

function New-Model {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $ModelObject,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Load the necessary assembly for HttpClient..."
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Creating HttpClient instance..."
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Set default request headers including authorization and accepted content type..."
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Construct the URL for the POST request"
        $url = "$OpenWebUiUri/api/v1/models/create"

        Write-Verbose "Convert payload to JSON format..."
        $jsonBody = $ModelObject | ConvertTo-Json -Depth 50

        Write-Verbose "Create StringContent with JSON payload"
        $content = New-Object System.Net.Http.StringContent($jsonBody, [System.Text.Encoding]::UTF8, "application/json")

        Write-Verbose "Send the POST request asynchronously and wait for the result..."
        $response = $client.PostAsync($url, $content).Result

        Write-Verbose "Check if the response indicates success"
        if ($response.IsSuccessStatusCode) {
            Write-Verbose "Request succeeded"
            $responseContent = $response.Content.ReadAsStringAsync().Result

            Write-Verbose "Convert JSON response to a PowerShell object"
            return $responseContent | ConvertFrom-Json
        }
        else {
            Write-Error "Request failed with status code $($response.StatusCode): $($response.ReasonPhrase)"
        }
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        Write-Verbose "Dispose of the HttpClient instance"
        $client.Dispose()
    }
}

$knowledge = @($KnowledgeIds | ForEach-Object {
    Get-Knowledge -KnowledgeId $_ -OpenWebUiApiKey $OpenWebUiApiKey -OpenWebUiUri $OpenWebUiUri
})

$suggestions = @($PromptSuggestions | ForEach-Object {
    @{ content = $_ }
})

$requestBody = @{
    id = $ModelName.ToLower().Replace(" ", "-")
    base_model_id = $BaseModel
    name = $ModelName
    meta = @{
        profile_image_url = "/static/favicon.png"
        description = $Description
        suggestion_prompts = $suggestions
        tags = @()
        capabilities = @{
            vision = $true
            citations = $true
        }
        #knowledge = $knowledge
    }
    params = @{
        temperature = 0.1
        top_k       = 10
        top_p       = 0.1
        num_ctx     = $ContextLength
        system      = $null
    }
    access_control = $null
}

$j = $requestBody | ConvertTo-Json -Depth 50

$a = New-Model -ModelObject $requestBody -OpenWebUiApiKey $OpenWebUiApiKey -OpenWebUiUri $OpenWebUiUri
Write-Host $a