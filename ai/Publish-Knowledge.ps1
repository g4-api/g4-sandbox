<#
.SYNOPSIS
    Script to configure and process RAG entries for the Open-WebUI service.

.DESCRIPTION
    This script sets up the configuration parameters for processing RAG entries in a Q&A knowledge base.
    It defines mandatory parameters for the input directory, Open-WebUI API key and URI, as well as the
    knowledge base name and description.

.PARAMETER InputDirectory
    The directory containing the input files. By default, it is set to a subdirectory named "rag-entries-qna"
    located in the same folder as the script.

.PARAMETER OpenWebUiApiKey
    The API key used for authenticating with the Open-WebUI service.

.PARAMETER OpenWebUiUri
    The base URI for the Open-WebUI service.

.PARAMETER KnowledgeName
    The name of the knowledge base that will be used for Automation Docs Q&A.

.PARAMETER KnowledgeDescription
    A short description detailing the content or purpose of the Automation Docs Q&A.

.EXAMPLE
    .\YourScript.ps1 -InputDirectory "C:\Data\rag-entries-qna" -OpenWebUiApiKey "sk-XXXXXXXXXXXX"
    -OpenWebUiUri "http://localhost:3000" -KnowledgeName "Automation Docs Q&A" -KnowledgeDescription "Automation Q&A details"
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "The directory containing the input files. Defaults to 'rag-entries-qna' in the script folder.")]
    [string]$InputDirectory = (Join-Path -Path $PSScriptRoot "rag-entries-qna"),

    [Parameter(Mandatory = $true, HelpMessage = "The API key used for authenticating with the Open-WebUI service.")]
    [string]$OpenWebUiApiKey,

    [Parameter(Mandatory = $true, HelpMessage = "The base URI of the Open-WebUI service.")]
    [string]$OpenWebUiUri,

    [Parameter(Mandatory = $true, HelpMessage = "The name of the knowledge base.")]
    [string]$KnowledgeName,

    [Parameter(Mandatory = $true, HelpMessage = "A description for the knowledge base.")]
    [string]$KnowledgeDescription
)

Write-Verbose "Input Directory      : $InputDirectory"
Write-Verbose "Open-WebUI API Key   : $OpenWebUiApiKey"
Write-Verbose "Open-WebUI URI       : $OpenWebUiUri"
Write-Verbose "Knowledge Name       : $KnowledgeName"
Write-Verbose "Knowledge Description: $KnowledgeDescription"

function Get-Files {
    <#
    .SYNOPSIS
        Retrieves the list of file IDs for a given knowledge resource from the Open-WebUI service,
        then retrieves each file's details to extract the file name.

    .DESCRIPTION
        This function calls the Open-WebUI API using the provided KnowledgeId, OpenWebUiApiKey, and OpenWebUiUri.
        It sends an HTTP GET request to retrieve the knowledge resource details and extracts the file IDs from
        the "files" array in the JSON response. For each file ID, it sends another GET request to retrieve the file
        details from `/api/v1/files/{fileId}`. It then extracts the file name from the response and returns an array of
        objects, each containing the file's Id and FileName. In case of an error, a verbose error message is written.

    .PARAMETER KnowlegdeId
        The identifier for the knowledge resource whose files are to be retrieved.

    .PARAMETER OpenWebUiApiKey
        The API key used for authenticating with the Open-WebUI service.

    .PARAMETER OpenWebUiUri
        The base URI of the Open-WebUI service.

    .EXAMPLE
        Get-Files -KnowlegdeId "abc123" -OpenWebUiApiKey "your-api-key" -OpenWebUiUri "https://example.com/api"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$KnowlegdeId,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Starting Get-Files for KnowledgeId: $KnowlegdeId"
    Write-Verbose "Loading System.Net.Http assembly..."
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Creating a new HttpClient instance..."
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Setting default request headers for authorization and JSON response..."
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Constructing the request URI for knowledge resource details..."
        $knowledgeUri = "$OpenWebUiUri/api/v1/knowledge/$KnowlegdeId"
        Write-Verbose "Constructed knowledge URI: $knowledgeUri"

        Write-Verbose "Sending GET request to retrieve knowledge details..."
        $knowledgeResponse = $client.GetAsync($knowledgeUri).Result
        Write-Verbose "Received response with status code: $($knowledgeResponse.StatusCode)"

        Write-Verbose "Reading knowledge response content..."
        $knowledgeContent = $knowledgeResponse.Content.ReadAsStringAsync().Result
        
        Write-Verbose "Parsing knowledge JSON response..."
        $jsonKnowledge = ConvertFrom-Json $knowledgeContent

        Write-Verbose "Extracting file IDs from the knowledge response..."
        $fileIds = $jsonKnowledge.files | ForEach-Object { $_.id }

        $resultArray = @()

        foreach ($fileId in $fileIds) {
            Write-Verbose "Processing file ID: $fileId"

            Write-Verbose "Constructing file details URI for file ID: $fileId"
            $fileUri = "$OpenWebUiUri/api/v1/files/$fileId"
            Write-Verbose "Constructed file URI: $fileUri"

            Write-Verbose "Sending GET request to retrieve file details..."
            $fileResponse = $client.GetAsync($fileUri).Result
            Write-Verbose "Received file response with status code: $($fileResponse.StatusCode)"

            Write-Verbose "Reading file response content..."
            $fileContent = $fileResponse.Content.ReadAsStringAsync().Result

            Write-Verbose "Parsing file JSON response..."
            $jsonFile = ConvertFrom-Json $fileContent

            Write-Verbose "Extracting file name from file details..."
            $fileName = $jsonFile.filename

            Write-Verbose "Creating object for file ID: $fileId with FileName: $fileName"
            $resultArray += [PSCustomObject]@{
                Id       = $fileId
                FileName = $fileName
            }
        }

        Write-Verbose "Returning the array of file objects with Id and FileName."
        return $resultArray
    }
    catch {
        Write-Error "An error occurred: $($_.Exception.Message)"
    }
    finally {
        Write-Verbose "Disposing HttpClient instance..."
        $client.Dispose()
    }

    return @()
}

function Initialize-Knowledge {
    <#
    .SYNOPSIS
        Initializes a knowledge entry by checking if it already exists and creating it if not.

    .DESCRIPTION
        This function retrieves an array of knowledge objects from the Open-WebUI service via a GET request to
        `/api/v1/knowledge/`. It then filters the returned objects to find one with a "name" field that matches the
        provided name. If a matching knowledge object is found, it is returned. If no match is found, the function
        calls the New-Knowledge function (which performs a POST) to create a new entry and returns that response.

    .PARAMETER Name
        The name of the knowledge entry to find or create.

    .PARAMETER Description
        The description of the knowledge entry. This is used when creating a new entry.

    .PARAMETER OpenWebUiApiKey
        The API key used for authenticating with the Open-WebUI service.

    .PARAMETER OpenWebUiUri
        The base URI of the Open-WebUI service (e.g., "https://api.example.com").

    .EXAMPLE
        $knowledge = Initialize-Knowledge -Name "PowerShell Scripting" `
                                          -Description "Learn PowerShell techniques" `
                                          -OpenWebUiApiKey "your_api_key_here" `
                                          -OpenWebUiUri "https://api.example.com"
        $knowledge | Format-List

    .NOTES
        Ensure that the Open-WebUI service is reachable and the API key is valid. This function assumes that a working
        New-Knowledge function (that performs a POST) is available in the session.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$Description,

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
        $url = "$OpenWebUiUri/api/v1/knowledge/"
        Write-Verbose "Constructed GET URL: $url"

        Write-Verbose "Sending GET request to retrieve all knowledge entries..."
        $response = $client.GetAsync($url).Result

        if(!$response.IsSuccessStatusCode) {
            Write-Error "GET request failed with status code $($response.StatusCode): $($response.ReasonPhrase)"
            return
        }

        Write-Verbose "GET request succeeded. Reading response content..."
        $content = $response.Content.ReadAsStringAsync().Result
        $knowledgeArray = $content | ConvertFrom-Json
        
        Write-Verbose "Filter for the knowledge entry matching the provided name"
        $found = $knowledgeArray | Where-Object { $_.name -eq $Name }
        if ($found) {
            Write-Verbose "Knowledge found. Returning the existing knowledge object."
            return $found
        }
        else {
            Write-Verbose "Knowledge not found. Creating a new knowledge entry..."
            return New-Knowledge `
                -Name            $Name `
                -Description     $Description `
                -OpenWebUiApiKey $OpenWebUiApiKey `
                -OpenWebUiUri    $OpenWebUiUri
        }
    }
    catch {
        Write-Error "An error occurred during initialization: $_"
    }
    finally {
        Write-Verbose "Disposing HttpClient instance used for GET request..."
        $client.Dispose()
    }
}

function New-Knowledge {
    <#
    .SYNOPSIS
        Publishes new knowledge data to the Open-WebUI service.

    .DESCRIPTION
        This function sends an HTTP POST request to the Open-WebUI service to create a new knowledge entry.
        The JSON body of the request includes the following structure:
    
        {
          "name": "string",
          "description": "string",
          "data": {},
          "access_control": {}
        }
    
        The function constructs this payload using the provided Name and Description, while the Data and
        Access_Control properties are initialized as empty objects. The JSON response is converted to a PowerShell
        object and returned.

    .PARAMETER Name
        The name of the knowledge entry to create.

    .PARAMETER Description
        A description of the knowledge entry.

    .PARAMETER OpenWebUiApiKey
        The API key used for authenticating with the Open-WebUI service.

    .PARAMETER OpenWebUiUri
        The base URI of the Open-WebUI service (e.g., "https://api.example.com").

    .EXAMPLE
        $knowledge = New-Knowledge -Name "PowerShell Scripting" -Description "Learn PowerShell techniques" `
                                   -OpenWebUiApiKey "your_api_key_here" -OpenWebUiUri "https://api.example.com"
        $knowledge | Format-List

    .NOTES
        Ensure that the Open-WebUI service is reachable and the API key is valid.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$Description,

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
        $url = "$OpenWebUiUri/api/v1/knowledge/create"
        
        Write-Verbose "Build the body payload as a hashtable"
        $body = @{
            name           = $Name
            description    = $Description
            data           = @{}  # Empty object for data
            access_control = @{}  # Empty object for access_control
        }

        Write-Verbose "Convert payload to JSON format..."
        $jsonBody = $body | ConvertTo-Json -Depth 5

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

function Publish-File {
    <#
    .SYNOPSIS
        Publishes a file to the Open-WebUI service using an HTTP POST request.

    .DESCRIPTION
        This function reads a file from the specified FilePath and publishes it to the given OpenWebUiUri.
        It uses a multipart/form-data HTTP request to send the file, setting the required authorization
        and content headers. The response from the server is converted from JSON and returned.

    .PARAMETER OpenWebUiUri
        The URI of the Open-WebUI service where the file will be published.

    .PARAMETER FilePath
        The full path to the file that will be published.

    .PARAMETER OpenWebUiApiKey
        The API key to be used for authentication with the Open-WebUI service.

    .EXAMPLE
        Publish-File -OpenWebUiUri "https://example.com/api/upload" -FilePath "C:\temp\file.txt" -OpenWebUiApiKey "your-api-key"

    .NOTES
        Ensure that the file exists at the specified FilePath and that the Open-WebUI service is reachable.
    #>
    param(
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Load the necessary assembly 'System.Net.Http'"
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Create a new HttpClient instance"
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Set default request headers"
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Create the multipart form data content"
        $multipartContent = New-Object System.Net.Http.MultipartFormDataContent

        Write-Verbose "Read the file bytes"
        $fileBytes   = [System.IO.File]::ReadAllBytes($FilePath)
        $fileContent = [System.Net.Http.ByteArrayContent]::new($fileBytes)

        Write-Verbose "Set the content disposition header so the server can recognize the form field name and file name"
        $fileName                               = [System.IO.Path]::GetFileName($FilePath)
        $disposition                            = New-Object System.Net.Http.Headers.ContentDispositionHeaderValue("form-data")
        $disposition.Name                       = '"file"'
        $disposition.FileName                   = '"' + $fileName + '"' 
        $fileContent.Headers.ContentDisposition = $disposition

        Write-Verbose "Add the file content to the multipart content"
        $multipartContent.Add($fileContent, "file", $fileName)

        Write-Verbose "Post the multipart content asynchronously and wait for the result"
        $response = $client.PostAsync($OpenWebUiUri, $multipartContent).Result
        $responseContent = $response.Content.ReadAsStringAsync().Result

        Write-Verbose "Converting the response content from JSON to PSObject"
        return ConvertFrom-Json $responseContent
    }
    finally {
        Write-Verbose "Disposing HttpClient instance"
        $client.Dispose()
    }
}

function Add-KnowledgeFile {
    <#
    .SYNOPSIS
        Adds a file (by file id) to a specific knowledge resource on the Open-WebUI service using an HTTP POST request.

    .DESCRIPTION
        This function sends an HTTP POST request to the endpoint `/api/v1/knowledge/{id}/file/add` with a JSON body
        containing the file id. The request is sent with the content type "application/json; charset=utf-8" and includes
        the required authorization header. The response from the server is converted from JSON to a PSObject and returned.
        In case of an error, an error message is written using Write-Error without throwing the exception further.

    .PARAMETER KnowlegeId
        The identifier for the knowledge resource to which the file will be added.

    .PARAMETER FileId
        The identifier of the file to add.

    .PARAMETER OpenWebUiApiKey
        The API key used for authenticating with the Open-WebUI service.

    .PARAMETER OpenWebUiUri
        The base URI of the Open-WebUI service.

    .EXAMPLE
        Add-KnowledgeFile -KnowlegeId "abc123" -FileId "file123" -OpenWebUiApiKey "your-api-key" -OpenWebUiUri "https://example.com/api"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$KnowlegeId,

        [Parameter(Mandatory=$true)]
        [string]$FileId,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory=$true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Starting Add-KnowledgeFile for KnowledgeId: $KnowlegeId with FileId: $FileId"
    Write-Verbose "Loading System.Net.Http assembly..."
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Creating a new HttpClient instance..."
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Setting default request headers for authorization and JSON response..."
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Constructing the add file URI for KnowledgeId: $KnowlegeId"
        $addUri = "$OpenWebUiUri/api/v1/knowledge/$KnowlegeId/file/add"
        Write-Verbose "Constructed add file URI: $addUri"

        Write-Verbose "Creating JSON body with file_id..."
        $bodyObject = @{ file_id = $FileId }
        $bodyJson = $bodyObject | ConvertTo-Json -Compress

        Write-Verbose "Creating StringContent with JSON body..."
        $content = New-Object System.Net.Http.StringContent($bodyJson, [System.Text.Encoding]::UTF8, "application/json")

        Write-Verbose "Sending POST request to the add file endpoint..."
        $response = $client.PostAsync($addUri, $content).Result
        Write-Verbose "Received response with status code: $($response.StatusCode)"

        Write-Verbose "Reading response content..."
        $responseContent = $response.Content.ReadAsStringAsync().Result

        Write-Verbose "Converting response content from JSON to PSObject..."
        return ConvertFrom-Json $responseContent
    }
    catch {
        Write-Error "An error occurred while adding the file: $($_.Exception.Message)"
    }
    finally {
        Write-Verbose "Disposing HttpClient instance..."
        $client.Dispose()
    }
}

function Update-File {
    <#
    .SYNOPSIS
        Updates a file on the Open-WebUI service using an HTTP POST request with a JSON payload.

    .DESCRIPTION
        This function reads the file from the specified FilePath as text and updates the file on the Open-WebUI service.
        It sends an HTTP POST request to the endpoint `/api/v1/files/{id}/data/content/update` with a JSON body:
        { "content": "the file content" }.
        The required authorization and content headers are set, and the server's JSON response is converted to a PSObject and returned.

    .PARAMETER FileId
        The identifier of the file to be updated.

    .PARAMETER FilePath
        The full path to the file that will be updated.

    .PARAMETER OpenWebUiApiKey
        The API key used for authenticating with the Open-WebUI service.

    .PARAMETER OpenWebUiUri
        The base URI of the Open-WebUI service.

    .EXAMPLE
        Update-File -FileId "abc123" -FilePath "C:\temp\file.txt" -OpenWebUiApiKey "your-api-key" -OpenWebUiUri "https://example.com/api"
    #>
    param(
        [CmdletBinding()]
        [Parameter(Mandatory = $true)]
        [string]$FileId,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiApiKey,

        [Parameter(Mandatory = $true)]
        [string]$OpenWebUiUri
    )

    Write-Verbose "Starting Update-File for FileId: $FileId with FilePath: $FilePath"
    Write-Verbose "Loading System.Net.Http assembly..."
    Add-Type -AssemblyName System.Net.Http

    Write-Verbose "Creating a new HttpClient instance..."
    $client = New-Object System.Net.Http.HttpClient

    try {
        Write-Verbose "Setting default request headers for authorization and JSON response..."
        $client.DefaultRequestHeaders.Add("Authorization", "Bearer $OpenWebUiApiKey")
        $client.DefaultRequestHeaders.Add("Accept", "application/json")

        Write-Verbose "Reading file content from: $FilePath"
        $fileContent = [System.IO.File]::ReadAllText($FilePath, [System.Text.Encoding]::UTF8)

        Write-Verbose "Constructing JSON body with file content..."
        $jsonBody = @{ content = $fileContent } | ConvertTo-Json -Depth 5

        Write-Verbose "Creating HTTP content with application/json and UTF-8 encoding..."
        $httpContent = [System.Net.Http.StringContent]::new($jsonBody, [System.Text.Encoding]::UTF8, "application/json")

        Write-Verbose "Constructing the file update URI for FileId: $FileId"
        $updateUri = "$OpenWebUiUri/api/v1/files/$FileId/data/content/update"
        Write-Verbose "Constructed update URI: $updateUri"

        Write-Verbose "Posting the JSON content to the update endpoint..."
        $response = $client.PostAsync($updateUri, $httpContent).Result
        Write-Verbose "Received response with status code: $($response.StatusCode)"

        Write-Verbose "Reading response content..."
        $responseContent = $response.Content.ReadAsStringAsync().Result

        Write-Verbose "Converting the response content from JSON to PSObject..."
        return ConvertFrom-Json $responseContent
    }
    finally {
        Write-Verbose "Disposing HttpClient instance..."
        $client.Dispose()
    }
}

Write-Verbose "Initializing knowledge metadata by retrieving or creating the knowledge entry."
$knowledgeMetadata = Initialize-Knowledge `
    -Name            $KnowledgeName `
    -Description     "..." `
    -OpenWebUiApiKey $OpenWebUiApiKey `
    -OpenWebUiUri    $OpenWebUiUri

Write-Verbose "Retrieving remote knowledge files collection for the specified knowledge entry."
$knowledgeFiles = Get-Files `
    -KnowlegdeId     $knowledgeMetadata.id `
    -OpenWebUiApiKey $OpenWebUiApiKey `
    -OpenWebUiUri    $OpenWebUiUri

Write-Verbose "Retrieve all files from the input directory '$($InputDirectory)'"
$files      = Get-ChildItem -Path $InputDirectory -File
$totalFiles = $files.Count
$i = 0

Write-Verbose "Loop through each file in the folder and upload it"
foreach ($file in $files) {
    $i++
    $percentComplete = [math]::Round(($i / $totalFiles) * 100, 0)
    
    Write-Progress `
        -Activity "Uploading Files" `
        -Status "Uploading $($file.Name) ($i of $totalFiles)" `
        -PercentComplete $percentComplete

    Write-Verbose "Uploading file $($file.FullName)"    
    $webUiUri = "$($OpenWebUiApiOpenWebUiUri)/api/v1/files"
    try {

        Write-Verbose "Checking if file '$($file.Name)' exists in the remote knowledge files collection."
        $existingFile = $knowledgeFiles | Where-Object { $_.FileName -eq $file.Name }
        if($existingFile) {
            Write-Verbose "File exists remotely; proceeding to update the file content using Update-File."
            Update-File `
                -FileId          $existingFile[0].Id `
                -FilePath        $file.FullName `
                -OpenWebUiApiKey $OpenWebUiApiKey `
                -OpenWebUiUri    $OpenWebUiUri
            continue
        }

        $fileResult = Publish-File `
            -OpenWebUiUri    $webUiUri `
            -FilePath        $file.FullName `
            -OpenWebUiApiKey $OpenWebUiApiKey

        $result = Add-KnowledgeFile `
            -KnowlegeId      $knowledgeMetadata.id `
            -FileId          $fileResult.id `
            -OpenWebUiApiKey $OpenWebUiApiKey `
            -OpenWebUiUri    $OpenWebUiUri
    }
    catch {
        Write-Error "Error uploading $($file.FullName): $_"
        continue
    }
}

Write-Progress -Activity "Uploading Files" -Completed
return $knowledgeMetadata.id