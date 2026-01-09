[CmdletBinding()]
param (
    [String]
    $cert_file_password,
    [String]
    $cert_file_path,
    [String]
    $ca_common_name = "placebo-pharma-CA-01",
    [String]
    $database_directory = "C:\windows\system32\certLog",
    [String]
    $log_directory = "C:\windows\system32\certLog"
)

# Check if CA is already installed

$caStatus = Get-Service CertSvc -ErrorAction Stop

if ($caStatus.Status) {
    Write-Output "CA is already installed with name: $($caStatus.Name)"
    $Ansible.Changed = $false
    exit 0
}

# Prepare CA parameters
$caParams = @{
    CAType            = "EnterpriseRootCA"
    DatabaseDirectory = $database_directory
    LogDirectory      = $log_directory
    Force             = $true
    KeyLength         = 4096
    HashAlgorithmName = "SHA256"
    CryptoProviderName = "RSA#Microsoft Software Key Storage Provider"
    ValidityPeriod    = "Years"
    ValidityPeriodUnits = 10
    CACommonName      = $ca_common_name
    CADNSName         = $ca_common_name
}

# Add certificate file parameters only if provided
if ($cert_file_path -and $cert_file_password) {
    $caParams["CertFile"] = $cert_file_path
    $caParams["CertFilePassword"] = ($cert_file_password | ConvertTo-SecureString -AsPlainText -Force)
}

# Install the CA
try {
    Install-ADcsCertificationAuthority @caParams -ErrorAction Stop
    
    $Ansible.Changed = $true
    Write-Output "Successfully installed new CA"
} catch {
    $errorMsg = $_.Exception.Message
    Write-Error "Failed to install CA: $errorMsg"
    $Ansible.Changed = $false
    throw $_
}