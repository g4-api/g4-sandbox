# ==================================================================================================
# Function / Script: Cross-Platform Self-Signed Client Certificate Generator (.NET)
# --------------------------------------------------------------------------------------------------
# Purpose
#   Create a self-signed X.509 certificate using .NET APIs (works on Windows/Linux/macOS),
#   then export a password-protected PFX and a public CER.
#
# Notes / Behavior
#   - Does NOT install into the OS certificate store (no Cert:\ usage).
#   - If you need the cert in Windows Cert Store, you can import the PFX afterward.
# ==================================================================================================

# -----------------------------
# Settings
# -----------------------------
$subjectName  = "CN=poc-client-cert"     # Subject / Common Name
$yearsValid   = 2                        # Validity period
$pfxPath      = ".\poc-client-cert.pfx"  # Output: includes private key
$cerPath      = ".\poc-client-cert.cer"  # Output: public cert only
$pfxPassword  = "sa"                     # Use a strong password for real use

# Convert password to SecureString (still needed if you later import into Windows store, etc.)
$pwd = ConvertTo-SecureString $pfxPassword -AsPlainText -Force

# -----------------------------
# Create RSA key pair
# -----------------------------
# Using RSA 2048 (reasonable baseline for dev/testing).
$rsa = [System.Security.Cryptography.RSA]::Create(2048)

try {
    # -----------------------------
    # Build certificate request
    # -----------------------------
    $hashAlgorithm = [System.Security.Cryptography.HashAlgorithmName]::SHA256
    $padding       = [System.Security.Cryptography.RSASignaturePadding]::Pkcs1

    $dn = New-Object System.Security.Cryptography.X509Certificates.X500DistinguishedName($subjectName)
    $req = New-Object System.Security.Cryptography.X509Certificates.CertificateRequest($dn, $rsa, $hashAlgorithm, $padding)

    # Key usage: DigitalSignature is typical for client auth (mTLS)
    $keyUsageFlags = [System.Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature
    $keyUsage      = New-Object System.Security.Cryptography.X509Certificates.X509KeyUsageExtension($keyUsageFlags, $false)
    $req.CertificateExtensions.Add($keyUsage)

    # Enhanced Key Usage (EKU): Client Authentication (important for mTLS client certs)
    $ekuOids = New-Object System.Security.Cryptography.OidCollection
    $ekuOids.Add((New-Object System.Security.Cryptography.Oid("1.3.6.1.5.5.7.3.2"))) | Out-Null  # clientAuth
    
    $eku = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($ekuOids, $false)
    $req.CertificateExtensions.Add($eku)

    # Basic constraints: not a CA
    $basicConstraints = New-Object System.Security.Cryptography.X509Certificates.X509BasicConstraintsExtension($false, $false, 0, $true)
    $req.CertificateExtensions.Add($basicConstraints)

    # -----------------------------
    # Create the self-signed cert
    # -----------------------------
    $notBefore = [DateTimeOffset]::UtcNow.AddMinutes(-5)  # small clock-skew tolerance
    $notAfter  = $notBefore.AddYears($yearsValid)

    $cert = $req.CreateSelfSigned($notBefore, $notAfter)

    # Re-wrap as exportable PFX-friendly object (helps across platforms and avoids ephemeral key issues)
    $pfxBytes = $cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $pfxPassword)
    $cert2 = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(
        $pfxBytes,
        $pfxPassword,
        [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    )

    # -----------------------------
    # Export PFX (private + public)
    # -----------------------------
    [System.IO.File]::WriteAllBytes(
        $pfxPath,
        $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx, $pfxPassword)
    )

    # -----------------------------
    # Export CER (public only)
    # -----------------------------
    [System.IO.File]::WriteAllBytes(
        $cerPath,
        $cert2.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
    )

    Write-Host "Created:"
    Write-Host " - $pfxPath"
    Write-Host " - $cerPath"
}
finally {
    # Always dispose keys to avoid leaks
    if ($rsa) { $rsa.Dispose() }
}