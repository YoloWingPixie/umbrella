$iadsName = "redIADS"
$saveLocation = "C:\dev"
$fileName = "iads"

function Set-PowerUnitName {
    param (
        $powerUnit,
        $receivingUnit
    )
    if ($powerUnit -eq "APU") {
        $powerUnit = $receivingUnit + '-' + "APU"
    }
    if ($powerUnit -eq "GPU") {
        $powerUnit = $receivingUnit + '-' + "GPU"
    }
    if ($powerUnit -eq "EP") {
        $powerUnit = $receivingUnit + '-' + "EP"
    }
    else {
        $powerUnit = $powerUnit
    }
    return $powerUnit
}

function Set-ConnectionNodeName {
    param (
        $connectionNode,
        $connectedUnit
    )
    if ($connectionNode -eq "CN") {
        $connectionNode = $connectedUnit + '-' + $connectionNode
    }
    else {
        $connectionNode = $connectionNode
    }
    return $connectionNode
}

function Convert-DefinitionContent {
    param (

        $DefinitionContent,
        $type
    )
    $leadingPattern = '(?smi)^.*'
    $trailingPattern = '(?smi)!END.*'

    $workingPattern = $LeadingPattern + $type
    $i = $DefinitionContent -replace $workingPattern
    $i = $i -replace $trailingPattern
    $i = $i.Split([Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)

    return $i
}

function Import-UmbrellaFile {
    [CmdletBinding()]
    param (

        [ValidateScript({
            if ( -Not ($_ | Test-Path)) {
                throw "File path provided is not valid"
            }
            if(-Not ($_ | Test-Path -PathType Leaf) ){
                throw "The file path provided is a folder. Please use the full path to the definition.umbrella file"
            }
            if($_ -notmatch "(\.umbrella)"){
                throw "The file specified in the path argument must be an .umbrella file"
            }
            return $true
        })]

        # The definition.umbrella file path
        [Parameter(Mandatory=$true)]
        [System.IO.FileInfo]
        $Path
    )
    
    begin { 
       Get-Content -Raw -Path $Path
    }
        
    process {
        
    }
    
    end {

    }
}
function New-UmbrellaSkynetFile {
    param (
        $fileName,
        $saveLocation,
        $iadsName
    )
    $preamble = @"

    do

    $iadsName = SkynetIADS:create('$iadsName')

"@

    if ($fileName -notmatch ".lua") {
        $fileName = $fileName+".lua"
    }
    $i = New-Item -Path $saveLocation -Name $fileName -ItemType "file" -Value $preamble

    return $i
}

$DefinitionContent = Import-UmbrellaFile -Path $path
$path = "C:\dev\umbrella\project\definition-example.umbrella"

$commandCenters = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!COMMAND.CENTERS'
$earlyWarningRadars = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!EWR'
$surfaceAirMissiles = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!SAM'
$pointDefense = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!POINT.DEFENSE'

$cc = [PSCustomObject]@{}
$ewr = [PSCustomObject]@{}
$sam = [PSCustomObject]@{}
$pd = [PSCustomObject]@{}

foreach ($comCen in $commandCenters) {
    $comUnit = $comCen.Split(',')[0].Trim()
    $comCN  = $comCen.Split(',')[1].Trim()
    $comPower = $comCen.Split(',')[2].Trim()
    $Name = $comUnit -replace ' ', ''
    
    $comCN =    Set-ConnectionNodeName -connectionNode $comCN -connectedUnit $comUnit
    $comPower = Set-PowerUnitName -powerUnit $comPower -receivingUnit $comUnit

    $comHash = @{
        Unit = $comUnit
        ConnectionNode = $comCN
        PowerUnit = $comPower
    }
    $comObj = [PSCustomObject]$comHash
    $cc | Add-Member -NotePropertyName $Name -NotePropertyValue $comObj
}

foreach ($group in $earlyWarningRadars) {
    $Unit = $group.Split(',')[0].Trim()
    $UnitCC  = $group.Split(',')[1].Trim()   
    $CN  = $group.Split(',')[2].Trim()
    $Power = $group.Split(',')[3].Trim()
    $Name = $Unit -replace ' ', ''
    $Name = $Name -replace "(-|`|#)", ''
    $Name = $Name -replace "'", ''
    
    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    $Hash = @{
        Unit = $Unit
        CommandCenter =  $UnitCC
        ConnectionNode = $CN
        PowerUnit = $Power
    }
    $Obj = [PSCustomObject]$Hash
    $ewr | Add-Member -NotePropertyName $Name -NotePropertyValue $Obj
}

foreach ($group in $surfaceAirMissiles) {
    $Unit = $group.Split(',')[0].Trim()
    $UnitCC  = $group.Split(',')[1].Trim()   
    $CN  = $group.Split(',')[2].Trim()
    $Power = $group.Split(',')[3].Trim()
    $ActAsEWR = $group.Split(',')[4].Trim()
    $EngZone = $group.Split(',')[5].Trim()
    $Name = $Unit -replace ' ', ''
    $Name = $Name -replace "(-|`|#)", ''
    $Name = $Name -replace "'", ''
    
    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    $Hash = @{
        Unit = $Unit
        CommandCenter =  $UnitCC
        ConnectionNode = $CN
        PowerUnit = $Power
        ActAsEWR = $ActAsEWR
        EngZone = $EngZone
    }
    $Obj = [PSCustomObject]$Hash
    $sam | Add-Member -NotePropertyName $Name -NotePropertyValue $Obj
}


$OutFile = New-UmbrellaSkynetFile -saveLocation $saveLocation -fileName $fileName -iadsName $iadsName



function Add-SamSite {
    param (
        $iadsName,
        $samName
    )
    Add-Content $OutFile "$iadsName`:addSameSite('$samName')"
}

