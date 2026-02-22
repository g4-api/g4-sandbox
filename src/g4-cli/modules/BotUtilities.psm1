<#
.SYNOPSIS
    Joins a base URI and a path segment, ensuring exactly one slash between them.

.DESCRIPTION
    The Join-Uri function concatenates two string parts�a base URI and a relative path�
    trimming any trailing slash from the base and any leading slash from the path,
    then inserting a single slash between. This prevents double-slashes or missing
    separators in constructed URIs.

.PARAMETER Base
    The base URI or URL prefix (e.g., "https://example.com/api").

.PARAMETER Path
    The relative segment or resource path to append (e.g., "/v1/items").

.EXAMPLE
    PS> Join-Uri -Base "https://hub.example.com/" -Path "/api/v4/ping"
    https://hub.example.com/api/v4/ping

.NOTES
    - Both inputs are mandatory and must not be null or empty.
    - Does not validate that the resulting URI is well-formed; use [uri] casting if needed.
#>
function Join-Uri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Base,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string] $Path
    )

    # Trim any trailing slash from the base, trim any leading slash from the path,
    # then combine with a single '/' separator.
    $normalizedBase = $Base.TrimEnd('/')
    $normalizedPath = $Path.TrimStart('/')

    # Return the combined URI string
    return "$($normalizedBase)/$($normalizedPath)"
}

Export-ModuleMember -Function Join-Uri