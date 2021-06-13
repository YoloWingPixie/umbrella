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

--Created with Umbrella

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

$cc = @()
$ccHash = @{}
$ewr = @()
$ewrHash = @{}
$sam = @()
$samHash = @{}
$pd = @()
$pdHash = @{}
[array]$Name = @()

foreach ($group in $commandCenters) {
    $Unit = $group.Split(',')[0].Split(';')[0].Trim()
    $UnitType = $group.Split(',')[0].Split(';')[1].Trim()
    $CN  = $group.Split(',')[1].Split(';')[0].Trim()
    if ($CN -ne 'nil') {
        $CNType = $group.Split(',')[1].Split(';')[1].Trim()
    }
    else {
        $CNType = "nil"
    }
    $Power = $group.Split(',')[2].Split(';')[0].Trim()
    if ($Power -ne 'nil') {
        $PowerType = $group.Split(',')[2].Split(';')[1].Trim()   
    }
    else {
        $PowerType = "nil"
    }
    $xName = $Unit -replace ' ', ''
    $Name = $Name + $xName

    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    $Hash = @{
        Unit = $Unit
        UnitType = $UnitType
        ConnectionNode = $CN
        ConnectionNodeType = $CNType
        PowerUnit = $Power
        PowerUnitType = $PowerType
    }
    $cc += [PSCustomObject]$Hash
}
Write-Host $Name

for ($i = 0; $i -lt $cc.Count; $i++) {
    $ccHash.($Name[$i]) = $cc[$i]
}

$ccObj = [PSCustomObject]$ccHash

[array]$Name = @()
foreach ($group in $earlyWarningRadars) {
    $Unit = $group.Split(',')[0].Trim()
    $UnitCC  = $group.Split(',')[1].Trim()
    $CN  = $group.Split(',')[2].Split(';')[0].Trim()
    if ($CN -ne 'nil') {
        $CNType = $group.Split(',')[2].Split(';')[1].Trim()
    }
    else {
        $CNType = "nil"
    }
    $Power = $group.Split(',')[3].Split(';')[0].Trim()
    if ($Power -ne 'nil') {
        $PowerType = $group.Split(',')[3].Split(';')[1].Trim()   
    }
    else {
        $PowerType = "nil"
    }   
    $xName = $Unit -replace ' ', ''
    $xName = $xName -replace "(-|`|#)", ''
    $xName = $xName -replace "'", ''
    $Name = $Name + $xName
    
    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    $Hash = @{
        Unit = $Unit
        CommandCenter =  $UnitCC
        ConnectionNode = $CN
        ConnectionNodeType = $CNType
        PowerUnit = $Power
        PowerUnitType = $PowerType
    }

    $ewr += [PSCustomObject]$Hash
}

for ($i = 0; $i -lt $ewr.Count; $i++) {
    $ewrHash.($Name[$i]) = $ewr[$i]
}

$ewjObj = [PSCustomObject]$ewrHash

[array]$Name = @()

foreach ($group in $surfaceAirMissiles) {
    $Unit = $group.Split(',')[0].Trim()
    $UnitCC  = $group.Split(',')[1].Trim()
    $CN  = $group.Split(',')[2].Split(';')[0].Trim()
    if ($CN -ne 'nil') {
        $CNType = $group.Split(',')[2].Split(';')[1].Trim()
    }
    else {
        $CNType = "nil"
    }
    $Power = $group.Split(',')[3].Split(';')[0].Trim()
    if ($Power -ne 'nil') {
        $PowerType = $group.Split(',')[3].Split(';')[1].Trim()   
    }
    else {
        $PowerType = "nil"
    }   
    $ActAsEWR = $group.Split(',')[4].Trim()
    $EngZone = $group.Split(',')[5].Trim()
    $xName = $Unit -replace ' ', ''
    $xName = $xName -replace "(-|`|#)", ''
    $xName = $xName -replace "'", ''
    $Name = $Name + $xName
    
    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    $Hash = @{
        Unit = $Unit
        CommandCenter =  $UnitCC
        ConnectionNode = $CN
        ConnectionNodeType = $CNType
        PowerUnit = $Power
        PowerUnitType = $PowerType
        ActAsEWR = $ActAsEWR
        EngZone = $EngZone
    }

    $sam += [PSCustomObject]$Hash
}

for ($i = 0; $i -lt $sam.Count; $i++) {
    $samHash.($Name[$i]) = $sam[$i]
}

$samObj = [PSCustomObject]$samHash


$OutFile = New-UmbrellaSkynetFile -saveLocation $saveLocation -fileName $fileName -iadsName $iadsName

function Add-CommandCenter {
    param (
        $iadsName,
        $cc
    )
    $iName = $cc.Value.Unit
    $content = "$iadsName`:addCommandCenter()"
    
}

function Add-SamSite {
    param (
        $iadsName,
        $sam
    )

    $iName = $sam.Value.Unit
    $content = "$iadsName`:addSamSite('$iName')"

    if ($sam.Value.EngZone -ne "nil") {
        $x = $sam.Value.EngZone
        $a = ":setEngagementZone($x)"
        $content = $content + $a
    }
    if ($sam.Value.ConnectionNode -ne "nil") {
        $cName = $sam.Value.ConnectionNode -replace " ", ""
        $nName = $sam.Value.ConnectionNode
        if ($sam.Value.ConnectionNodeType -eq "unit") {
            Add-Content $OutFile "$cName = Unit.getByName($nName)"
        }
        else {
            Add-Content $OutFile "$cName = StaticObject.getByName($nName)"
        }
        $b = ":addConnectionNode($nName)"
        $content = $content + $b

    }
    if ($sam.Value.PowerUnit -ne "nil") {
        $pName = $sam.Value.PowerUnit -replace " ", ""
        $uName = $sam.Value.PowerUnit
        if ($sam.Value.PowerUnitType -eq "unit") {
            Add-Content $OutFile "$pName = Unit.getByName($uName)"
        }
        else {
            Add-Content $OutFile "$pName = StaticObject.getByName($uName)"
        }
        $c = ":addPowerSource($pName)"
        $content = $content + $c

    }
    if ($sam.Value.ActAsEWR -eq 'true') {
        $d = ":setActAsEW(true)"
        $content = $content + $d
    }


    Add-Content $OutFile $content
}

Add-Content $OutFile @'

-------- SAMs -------

'@

$samObj.psobject.Properties |  ForEach-Object -Process{ Add-SamSite -sam $_ -iadsName $iadsName }


Add-Content $OutFile @"

$iadsName`:setupSAMSitesAndThenActivate()

end

"@
