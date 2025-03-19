<#
.SYNOPSIS
    Processes a Swagger JSON file and extracts a specific schema definition,
    converts it to a JSON Schema with external definitions, and writes the output to a file.

.DESCRIPTION
    This script loads a Swagger JSON document from a file, extracts a specific schema (by name)
    along with any nested definitions referenced via "$ref", and then creates a new JSON Schema.
    It updates certain properties, such as setting the "$schema" property and placing all definitions
    under the "$defs" property. The final output is written to a file with a kebab-case filename derived
    from the schema name.

.PARAMETER SwaggerJsonPath
    The file path to the Swagger JSON document.

.PARAMETER SchemaName
    The name of the schema to extract from the Swagger JSON.

.PARAMETER OutputDirectory
    The directory where the output file will be saved. Defaults to the current script's directory.

.EXAMPLE
    .\Process-SwaggerSchema.ps1 -SwaggerJsonPath "swagger.json" -SchemaName "MySchema" -OutputDirectory "C:\Output"

.NOTES
    This script leverages helper functions Get-Schema, Get-Refs, Get-Defs, and Convert-PascalToKebab.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SwaggerJsonPath,

    [Parameter(Mandatory = $true)]
    [string]$SchemaName,

    # Default to the directory of the current script if not provided.
    [string]$OutputDirectory = $PSScriptRoot
)

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

function Get-Defs {
    <#
    .SYNOPSIS
        Recursively retrieves schema definitions from a Swagger JSON schema.

    .DESCRIPTION
        This function takes a Swagger JSON schema (as a PSObject) and an array of definition names,
        then recursively extracts the definitions and any nested references found within each definition.
        It uses a hashtable to track visited definitions to prevent processing the same definition multiple times.
        The function returns an array of hashtables, each containing a definition's name and its corresponding schema.

    .PARAMETER Schema
        The Swagger JSON schema object containing definitions under components.schemas.

    .PARAMETER DefNames
        An array of definition names to extract from the Swagger JSON schema.

    .PARAMETER Visited
        (Optional) A hashtable used internally to track visited definitions and avoid infinite recursion.
        Do not supply this parameter manually; it is managed internally.

    .EXAMPLE
        $swagger = Get-Content -Raw -Path "swagger.json" | ConvertFrom-Json
        $defs = Get-Defs -Schema $swagger -DefNames @("User", "Product")
        $defs | Format-Table

    .NOTES
        If a requested definition is not found, a warning is written and the definition is skipped.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Schema,

        [Parameter(Mandatory = $true)]
        [string[]]$DefNames,

        # Hashtable to track definitions that have already been processed to avoid recursion loops.
        [Hashtable]$Visited = @{}
    )

    # Initialize an empty array to store the results.
    $results = @()

    # Loop through each definition name in the provided array.
    foreach ($name in $DefNames) {
        # If this definition has already been processed, skip to the next.
        if ($Visited.ContainsKey($name)) {
            continue
        }

        # Mark the current definition as visited.
        $Visited[$name] = $true

        # Create a result object with default values.
        $result = @{
            Name   = $name
            Schema = $null
        }

        # Check if the definition exists in the provided Swagger schema.
        if ($Schema.components.schemas.PSObject.Properties[$name]) {
            # Extract the definition schema from the Swagger JSON.
            $result.Schema = $Schema.components.schemas.$name
            $results += $result
        }
        else {
            # If the definition is not found, output a warning.
            Write-Warning "Definition '$name' not found in the schema."
        }

        # If a valid schema was found, search for any nested "$ref" references.
        if ($result.Schema) {
            # Convert the schema to JSON and use Get-Refs to extract reference names.
            $references = Get-Refs -JsonContent (ConvertTo-Json $result.Schema -Depth 10)
            if ($references.Length -gt 0) {
                # Recursively call Get-Defs to process the referenced definitions.
                $collection = Get-Defs -Schema $Schema -DefNames $references -Visited $Visited
                $results += $collection
            }
        }
    }

    # Return the final collection of definitions.
    return $results
}

function Get-Refs {
    <#
    .SYNOPSIS
        Extracts reference names from a JSON content string.

    .DESCRIPTION
        This function parses a JSON content string to extract all "$ref" values using a regular expression.
        It splits each "$ref" value by '/' and returns the last part as the reference name.
        If the input JSON is empty, null, or an error occurs during processing, it returns an empty array.

    .PARAMETER JsonContent
        The JSON content as a string from which to extract "$ref" values.

    .EXAMPLE
        $json = Get-Content -Path "swagger.json" -Raw
        $refs = Get-Refs -JsonContent $json
        Write-Output $refs

    .NOTES
        The function uses a regex pattern to locate "$ref" properties and extracts the referenced name.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonContent
    )

    try {
        # Check if the JSON content is null, empty, or consists only of whitespace.
        if ([string]::IsNullOrWhiteSpace($JsonContent)) {
            Write-Verbose "Input JSON content is empty or null."
            return @()
        }

        # Define the regex pattern to match "$ref" properties and capture their values.
        $pattern = '"\$ref"\s*:\s*"(.*?)"'
        
        # Execute the regex match on the JSON content.
        $matches = [regex]::Matches($JsonContent, $pattern)
        
        # Initialize an array to store the extracted reference names.
        $rootRefs = @()

        # Loop through each regex match found.
        foreach ($match in $matches) {
            # Ensure the match has at least one captured group with a non-empty value.
            if ($match.Groups.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($match.Groups[1].Value)) {
                # Capture the value of the "$ref" property.
                $refValue = $match.Groups[1].Value

                # Split the reference value on '/' to isolate parts of the reference.
                $parts = $refValue -split '/'
                if ($parts.Length -gt 0) {
                    # The last part of the split is assumed to be the reference name.
                    $refName = $parts[-1]
                    $rootRefs += $refName
                }
            }
        }

        # Return the array of extracted reference names.
        return $rootRefs
    }
    catch {
        # On any error, output a verbose error message and return an empty array.
        Write-Verbose "An error occurred: $($_.Exception.Message)"
        return @()
    }
}

function Get-Schema {
    <#
    .SYNOPSIS
        Retrieves a specific schema definition from a Swagger JSON source.

    .DESCRIPTION
        This function loads a Swagger JSON document from either a remote URL or a local file,
        then extracts and returns a specific schema definition by name.
        It returns a hashtable containing:
          - The complete Swagger JSON (Definition)
          - The raw JSON string of the requested schema (RowSchema)
          - The parsed schema object (Schema)

    .PARAMETER JsonUri
        The URI or file path to the Swagger JSON document.

    .PARAMETER SchemaName
        The name of the schema definition to extract from the Swagger JSON.

    .EXAMPLE
        Get-Schema -JsonUri "https://api.example.com/swagger.json" -SchemaName "MySchema"

    .NOTES
        If the specified schema is not found, the function will output an error and exit.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$JsonUri,

        [Parameter(Mandatory = $true)]
        [string]$SchemaName
    )

    # Check if the provided URI is a web address (HTTP/HTTPS) or a local file path.
    if ($JsonUri -match "^https?://") {
        Write-Verbose "Loading Swagger JSON from URL: $JsonUri"
        # Retrieve JSON data from the URL using Invoke-RestMethod.
        $swagger = Invoke-RestMethod -Uri $JsonUri
    } else {
        Write-Verbose "Loading Swagger JSON from file: $JsonUri"
        # Read the JSON file as a single string and convert it to a PowerShell object.
        $swagger = Get-Content $JsonUri -Raw | ConvertFrom-Json
    }

    # Verify that the requested schema exists within the Swagger JSON.
    if (-not $swagger.components.schemas.PSObject.Properties[$SchemaName]) {
        Write-Error "Schema '$SchemaName' not found in the Swagger JSON."
        exit 1
    }

    # Convert the specific schema definition back to a JSON string to preserve its raw format,
    # using a high depth value to support nested objects.
    $rawSchema = $swagger.components.schemas.$SchemaName | ConvertTo-Json -Depth 50

    # Return a hashtable containing:
    #   - The entire Swagger JSON document.
    #   - The raw JSON string of the requested schema.
    #   - The parsed schema object.
    return @{
        Definition = $swagger
        RowSchema  = $rawSchema
        Schema     = $swagger.components.schemas.$SchemaName
    }
}

# Load the root schema and extract the specified schema definition.
$rootSchema = Get-Schema -JsonUri $SwaggerJsonPath -SchemaName $SchemaName

# Extract the "$ref" references from the raw schema JSON.
$rootRefs = Get-Refs -JsonContent $rootSchema.RowSchema

# Recursively get all nested definitions referenced by the root schema.
$rootDefs = Get-Defs -Schema $rootSchema.Definition -DefNames $rootRefs

# Set the output schema to the extracted root schema.
$outputScheme = $rootSchema.Schema

# Update the schema properties:
# Add "$schema" property with a link to the JSON Schema draft.
Add-Member -InputObject $outputScheme -MemberType NoteProperty -Name '$schema' -Value "./schema-draft.json" -Force

# Initialize the "$defs" property as an empty object; definitions will be added here.
Add-Member -InputObject $outputScheme -MemberType NoteProperty -Name '$defs' -Value @{} -Force

# Set the "title" property of the schema to the provided SchemaName.
Add-Member -InputObject $outputScheme -MemberType NoteProperty -Name 'title' -Value $SchemaName -Force

# Create a PSCustomObject to store all definitions.
$definitions = [PSCustomObject]@{}

# Loop through each root definition, adding each to the definitions object.
foreach ($rootDef in $rootDefs) {
    Add-Member -InputObject $definitions -MemberType NoteProperty -Name $rootDef.Name -Value $rootDef.Schema -Force
}

# Convert the modified output scheme to JSON text.
$outputJsonData = $outputScheme | ConvertTo-Json -Depth 50

# Replace the original Swagger reference path with the new JSON Schema "$defs" reference.
$outputJsonData = $outputJsonData.Replace('#/components/schemas/', '#/$defs/')

# Convert the updated JSON text back into a PowerShell object.
$outputScheme = $outputJsonData | ConvertFrom-Json

# Convert the definitions object to JSON.
$defsJson = $definitions | ConvertTo-Json -Depth 50

# Replace Swagger reference paths in the definitions JSON with the new "$defs" reference.
$updatedDefsJson = $defsJson.Replace('#/components/schemas/', '#/$defs/')

# Convert the updated definitions JSON back into a PowerShell object.
$updatedDefs = $updatedDefsJson | ConvertFrom-Json

# Update the "$defs" property in the output scheme with the final definitions.
$outputScheme.'$defs' = $updatedDefs

# Generate the output file path using the OutputDirectory and converting the schema name to kebab-case.
$outputFilePath = Join-Path -Path $OutputDirectory -ChildPath "$(Convert-PascalToKebab -InputString $SchemaName).json"

# Write the final JSON schema to the output file, compressing the JSON output.
Set-Content -Path $outputFilePath -Value (ConvertTo-Json -InputObject $outputScheme -Depth 50 -Compress)
