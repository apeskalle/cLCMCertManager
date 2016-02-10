######################################################################################
# Ths6da67e Get-TargetResource cmdlet.
# This function will get the certificate if it exists and return all information
######################################################################################
function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param (
        [parameter(Mandatory = $false)][System.String]$TemplateName,
        [parameter(Mandatory = $false)][System.String]$CertName,
        [parameter(Mandatory = $false)][System.String]$SubjectAlternativeName,
        [parameter(Mandatory = $false)][DateTime]$ExpireAfter
	   )

    #Gather currently configured certificate information
    [string]$ActiveThumbprint = (Get-DscLocalConfigurationManager).CertificateID
    $ActiveCert = Get-Childitem cert:\LocalMachine\MY | where-object { $_.thumbprint -eq $ActiveThumbprint}

    #Pull Template and SAN Information
    $ActiveTemplate = ($ActiveCert.extensions | where-object{$_.oid.Friendlyname -match "Certificate Template Information"}).format(0).split(",")[0]
    $ActiveTemplate = $ActiveTemplate.trimstart("Template=").split("(")[0]

    $SANInfo = ($ActiveCert.extensions | where-object{$_.oid.Friendlyname -match "subject alternative name"}).Format(0).split(",")
    $SANInfo = $SANinfo.trimstart()
   
    $ReturnValue = @{
		CertName = $ActiveCert.Subject
        Thumbprint = $ActiveCert.Thumbprint
        TemplateName = $ActiveTemplate
        SubjectAlternativeName = $SANInfo
        ExpireAfter = $ActiveCert.NotAfter
        }

    $ReturnValue
}

######################################################################################
# The Set-TargetResource cmdlet.
# This function will pass the "apply" switch back to the validate function
######################################################################################
function Set-TargetResource
{
	[CmdletBinding()]
	param (
        [parameter(Mandatory = $true)][System.String]$OutPath,
        [parameter(Mandatory = $false)][ValidateSet("Computer","FQDN","GUID")][System.String]$OutputName = "Computer",
        [parameter(Mandatory = $false)][PSCredential]$OutPathCredential,
        [parameter(Mandatory = $false)][System.String]$TemplateName,
        [parameter(Mandatory = $false)][System.String]$CertName,
        [parameter(Mandatory = $false)][System.String]$SubjectAlternativeName,
        [parameter(Mandatory = $false)][DateTime]$ExpireAfter
	   )

    ValidateProperties @PSBoundParameters -Apply

}

######################################################################################
# The Test-TargetResource cmdlet.
# This function will only return a $true $false on compliance
######################################################################################
function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param (
        [parameter(Mandatory = $true)][System.String]$OutPath,
        [parameter(Mandatory = $false)][ValidateSet("Computer","FQDN","GUID")][System.String]$OutputName = "Computer",
        [parameter(Mandatory = $false)][PSCredential]$OutPathCredential,
        [parameter(Mandatory = $false)][System.String]$TemplateName,
        [parameter(Mandatory = $false)][System.String]$CertName,
        [parameter(Mandatory = $false)][System.String]$SubjectAlternativeName,
        [parameter(Mandatory = $false)][DateTime]$ExpireAfter
	   )

ValidateProperties @PSBoundParameters

}


######################################################################################
# The ValidateProperties cmdlet.
# This function accepts an -apply flag and "does the work"
######################################################################################
function ValidateProperties
{
param (
        [parameter(Mandatory = $true)][System.String]$OutPath,
        [parameter(Mandatory = $false)][ValidateSet("Computer","FQDN","GUID")][System.String]$OutputName = "Computer",
        [parameter(Mandatory = $false)][PSCredential]$OutPathCredential,
        [parameter(Mandatory = $false)][System.String]$TemplateName,
        [parameter(Mandatory = $false)][System.String]$CertName,
        [parameter(Mandatory = $false)][System.String]$SubjectAlternativeName,
        [parameter(Mandatory = $false)][DateTime]$ExpireAfter,
        [Switch]$Apply
	   )
    
    #Set initial TestedOK value to true, which will be called later to see if all variables are still valid
    [boolean]$TestedOK = $true
    [boolean]$CertNeedsUpdate = $false

    #Gather currently configured certificate information
    [string]$ActiveThumbprint = (Get-DscLocalConfigurationManager).CertificateID
    $ActiveCert = Get-Childitem cert:\LocalMachine\MY | where-object { $_.thumbprint -eq $ActiveThumbprint}
    $ActiveTemplate = ($ActiveCert.extensions | where-object{$_.oid.Friendlyname -match "Certificate Template Information"}).format(0).split(",")[0]
    $ActiveTemplate = $ActiveTemplate.trimstart("Template=").split("(")[0]
    $ActiveSANInfo = ($ActiveCert.extensions | where-object{$_.oid.Friendlyname -match "subject alternative name"}).Format(0).split(",")
    $ActiveSANInfo = $ActiveSANinfo.trimstart()

    #Gather "Best Match" Certificate by first grabbing all valid certificate candidates
    $BestMatchCert = Get-Childitem cert:\LocalMachine\MY

    #Use parameter-defined criteria to filter down the list, then pick the longest valid time from remaining choices
    If ($CertName) {
        $BestMatchCert = $BestMatchCert | Where-Object {$_.Subject -eq $CertName}
        }
    If ($TemplateName) {
        $gather = @()
        $tempname = $null
        $BestMatchCert = ($BestMatchCert | Where-Object {($_.extensions.oid.FriendlyName -match "Certificate Template Information")})
            ForEach ($cert in $BestMatchCert) {
            $tempname = ($cert.extensions | where-object{$_.oid.Friendlyname -match "Certificate Template Information"}).format(0).split(",")[0]
            $tempname = $tempname.trimstart("Template=").split("(")[0]
            If($tempname -eq $templateName) {$gather+=$Cert}
            }#End ForEach Loop
        $BestMatchCert = $gather
        }
    If ($SubjectAlternativeName) {
        $gather = @()
        $tempname = $null
        $BestMatchCert = ($BestMatchCert | Where-Object {($_.extensions.oid.FriendlyName -match "subject alternative name")})
            ForEach ($cert in $BestMatchCert) {
            $tempname =  ($cert.extensions | where-object{$_.oid.Friendlyname -match "subject alternative name"}).Format(0).split(",")
            $tempname = $tempname.trimstart()
            If($tempname -contains $SubjectAlternativeName) {$gather+=$Cert}
            }#End ForEach Loop
        $BestMatchCert = $gather
        }
    If ($ExpireAfter) {
        $BestMatchCert = $BestMatchCert | Where-Object {$_.NotAfter -gt $ExpireAfter}
        }
    
    #trim and select final cert
    $BestMatchCert = $BestMatchCert | Sort-Object NotAfter -Descending | Select -First 1
    $BestMatchTemplate = ($BestMatchCert.extensions | where-object{$_.oid.Friendlyname -match "Certificate Template Information"}).format(0).split(",")[0]
    $BestMatchTemplate = $BestMatchTemplate.trimstart("Template=").split("(")[0]
    $BestMatchSANInfo =  ($BestMatchCert.extensions | where-object{$_.oid.Friendlyname -match "subject alternative name"}).Format(0).split(",")
    $BestMatchSANInfo = $BestMatchSANinfo.trimstart()

    #Compare ActiveCert to BestMatchCert and then update share if they differ
    If ($ActiveCert.thumbprint -ne $BestMatchCert.thumbprint) {
        
        #Generate Login Credentials if needed
        If ($OutPathCredential) {
            ($oldToken, $context, $newToken) = ImpersonateAs -cred $OutPathCredential
            }

        #Grab appropriate filename based on switch
        Switch ($OutputName) {
            Computer {$FileName = $env:COMPUTERNAME}
            FQDN {$FileName = $env:COMPUTERNAME+"."+(Get-WmiObject win32_computersystem).Domain}
            GUID {$FileName = (Get-DscLocalConfigurationManager).ConfigurationID}
            }


        #Check for the existence of the target path
        If(Test-Path -Path ($OutPath+'\'+$FileName+'.cer')) {
            write-verbose "cert found, comparing thumbprints"
            # X509Certificate2 object that will represent the certificate
            $CertPrint = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2
     
            # Imports the certificate from file to x509Certificate object
            $certPrint.Import($OutPath+'\'+$FileName+'.cer')

            #Set Flag to Update if Thumbprints dont match
            If(($CertPrint.Thumbprint -ne $BestMatchCert.Thumbprint) -and $Apply) {
                $CertNeedsUpdate = $true
                }
            
            If(($CertPrint.Thumbprint -ne $BestMatchCert.Thumbprint) -and !$Apply) {
                $TestedOK = $false
                }
            }#End File Found

        #Can't find a file, next steps
        Else {
            #Test writing to the certstore, then commit to adding a file
            Try {
                Write-Verbose "test writing to $OutPath ..."
                new-item "$OutPath\$FileName.txt" -ItemType File | Out-Null
                remove-item "$OutPath\$FileName.txt"
                $CertNeedsUpdate = $true
                }
            Catch {
                $TestedOK = $false
                Throw "can't write to $OutPath..."
                }
            }

        #Update The Certificate if Flagged
        IF(($CertNeedsUpdate -eq $true) -and $BestMatchCert -and $Apply) {
            Try {
                write-verbose "Attempting to write to $OutPath\$FileName.cer"
                $DestinationFile = $OutPath+'\'+$FileName+'.cer'
                Export-Certificate -FilePath $DestinationFile -Cert $BestMatchCert | Out-Null
                }
            Catch {
                $TestedOK = $false
                Throw "cannot write "+$DestinationFile
                }
            }#End CertUpdate

        }
    
    #Logout if logged in
    if ($context) {
            $context.Undo()
            $context.Dispose()
            CloseUserToken($newToken)
        }

    If (!($Apply)) {
        Return $TestedOK
        }
}

######################################################################################
# The below functions are used for user impersonation
# There are 3 functions in total
######################################################################################
function Get-ImpersonatetLib
{
    if ($script:ImpersonateLib)
    {
        return $script:ImpersonateLib
    }

    $sig = @'
[DllImport("advapi32.dll", SetLastError = true)]
public static extern bool LogonUser(string lpszUsername, string lpszDomain, string lpszPassword, int dwLogonType, int dwLogonProvider, ref IntPtr phToken);

[DllImport("kernel32.dll")]
public static extern Boolean CloseHandle(IntPtr hObject);
'@ 
   $script:ImpersonateLib = Add-Type -PassThru -Namespace 'Lib.Impersonation' -Name ImpersonationLib -MemberDefinition $sig 

   return $script:ImpersonateLib
    
}

function ImpersonateAs([PSCredential] $cred)
{
    [IntPtr] $userToken = [Security.Principal.WindowsIdentity]::GetCurrent().Token
    $userToken
    $ImpersonateLib = Get-ImpersonatetLib

    $bLogin = $ImpersonateLib::LogonUser($cred.GetNetworkCredential().UserName, $cred.GetNetworkCredential().Domain, $cred.GetNetworkCredential().Password, 
    9, 0, [ref]$userToken)
    
    if ($bLogin)
    {
        $Identity = New-Object Security.Principal.WindowsIdentity $userToken
        $context = $Identity.Impersonate()
    }
    else
    {
        throw "Can't Logon as User $cred.GetNetworkCredential().UserName."
    }
    $context, $userToken
}

function CloseUserToken([IntPtr] $token)
{
    $ImpersonateLib = Get-ImpersonatetLib

    $bLogin = $ImpersonateLib::CloseHandle($token)
    if (!$bLogin)
    {
        throw "Can't close token"
    }
}

#  FUNCTIONS TO BE EXPORTED 
Export-ModuleMember -Function *-TargetResource
