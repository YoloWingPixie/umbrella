$iadsName = "redIADS"
$saveLocation = "C:\dev"
$fileName = "iads"

#Set the name of the power unit to the name of recieving unit + "-APU" or other accepted tag, UNLESS a specific name was given.
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

#Set the name of the connection node to the name of the connected unit + "-CN" UNLESS a specific name was given.
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

# Generalized function to extract lists of units out of their configuration section
function Convert-DefinitionContent {
    param (

        #The result of Import-UmbrellaFile
        $DefinitionContent,

        #The type of unit being extracted from the config (!COMMAND, !EWR, !SAM, etc)
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

# Import the Umbrella content definition file.
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

#Create a new Skynet file with a specific file name, in a save location, and populate it with the required preamble.
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
    #If .lua was not given in the fileName, add it
    if ($fileName -notmatch ".lua") {
        $fileName = $fileName+".lua"
    }
    #Create a return variable that can be used to reference the created file
    $i = New-Item -Path $saveLocation -Name $fileName -ItemType "file" -Value $preamble

    return $i
}

#Import the config definitions
$path = "C:\dev\umbrella\project\definition-example.umbrella"
$DefinitionContent = Import-UmbrellaFile -Path $path

# Extract the unit lists from the definitions
$commandCenters = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!COMMAND.CENTERS'
$earlyWarningRadars = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!EWR'
$surfaceAirMissiles = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!SAM'
$pointDefense = Convert-DefinitionContent -DefinitionContent $DefinitionContent -type '!POINT.DEFENSE'

<# 
Create an array and hash table for each type of unit, plus a Name array.

The goal here is to get an array of PSCustomObjects that then gets passed to a hash table,
and then use that hash table to create a parent PSCustomObject for easy reference of all the units,
and their properties.

#>
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

    #Split the name of the unit from the element string, and then from the unit type
    $Unit = $group.Split(',')[0].Split(';')[0].Trim()
    $UnitType = $group.Split(',')[0].Split(';')[1].Trim()

    #Split the name of the connection node from the element string, and then from the connection unit type
    $CN  = $group.Split(',')[1].Split(';')[0].Trim()

    #If the CN was not nil, get the type of the CN, else nil.
    if ($CN -ne 'nil') {
        $CNType = $group.Split(',')[1].Split(';')[1].Trim()
    }
    else {
        $CNType = "nil"
    }

    #Split the name of the power unit from the element string, and then from the power unit type
    $Power = $group.Split(',')[2].Split(';')[0].Trim()

    #If the power unit is not nil, get the type of the power unit, else nil.
    if ($Power -ne 'nil') {
        $PowerType = $group.Split(',')[2].Split(';')[1].Trim()   
    }
    else {
        $PowerType = "nil"
    }

    #Create an object friendly no-space version of the unit name, which will be the name of the child object within the parent object.
    $xName = $Unit -replace ' ', ''
    $Name = $Name + $xName

    #Generates the CN and power unit names, unless a specific name was given
    $CN =    Set-ConnectionNodeName -connectionNode $CN -connectedUnit $Unit
    $Power = Set-PowerUnitName -powerUnit $Power -receivingUnit $Unit

    #The unit's hash table which contains the unit's name, the unit type (In the case of a command center), 
    #the connection node, the connection node unit type, the power unit, and the power unit type.
    $Hash = @{
        Unit = $Unit
        UnitType = $UnitType
        ConnectionNode = $CN
        ConnectionNodeType = $CNType
        PowerUnit = $Power
        PowerUnitType = $PowerType
    }

    #Add the above hash table to the command center array as an object
    $cc += [PSCustomObject]$Hash
}

#For loop to add the contents of each object in the array and its name in to a hash table
for ($i = 0; $i -lt $cc.Count; $i++) {
    $ccHash.($Name[$i]) = $cc[$i]
}

#Convert the hash table to a PSCustom Object.
#We can now reference specific properties by using $ccObj.Unit.ConnectionNode for example
$ccObj = [PSCustomObject]$ccHash

#clear the Name array
[array]$Name = @()

#The same process now repeats for EWRs, SAMs, and PDs
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

#Make the Skynet lua file
$OutFile = New-UmbrellaSkynetFile -saveLocation $saveLocation -fileName $fileName -iadsName $iadsName

#WIP function
function Add-CommandCenter {
    param (
        $iadsName,
        $cc
    )
    $iName = $cc.Value.Unit
    $content = "$iadsName`:addCommandCenter()"
    
}

#Function to generate SAM site entries in the lua file
function Add-SamSite {
    param (
        $iadsName,

        # As seen later, we're passing $samObj.psobject.Properties |  ForEach-Object to this function so $sam should pretty much always
        # $_
        $sam
    )

    #iName is the literal unit name
    $iName = $sam.Value.Unit
    
    #content is the variable that actually gets written to the Skynet file for each SAM site. It starts with a simple add
    #and as options are added from loops, these get appended.
    $content = "$iadsName`:addSamSite('$iName')"

    #Add the engagement zone
    if ($sam.Value.EngZone -ne "nil") {
        $x = $sam.Value.EngZone
        $a = ":setEngagementZone($x)"
        $content = $content + $a
    }

    #Add the connection node
    if ($sam.Value.ConnectionNode -ne "nil") {

        #cName is a no-space version of the name for the declared lua variable
        $cName = $sam.Value.ConnectionNode -replace " ", ""

        #nName is the literal unit name in ME
        $nName = $sam.Value.ConnectionNode

        #if the connection node is a unit, add it ias a unit, else add it as a static object.
        if ($sam.Value.ConnectionNodeType -eq "unit") {
            Add-Content $OutFile "$cName = Unit.getByName($nName)"
        }
        else {
            Add-Content $OutFile "$cName = StaticObject.getByName($nName)"
        }
        $b = ":addConnectionNode($nName)"
        $content = $content + $b

    }

    #Add the power source. Perform the same steps as above.
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

    #If the SAM should act as an EWR, add that to the content
    if ($sam.Value.ActAsEWR -eq 'true') {
        $d = ":setActAsEW(true)"
        $content = $content + $d
    }

    #Write the result of $content of this loop, to the lua file.
    Add-Content $OutFile $content
}

Add-Content $OutFile @'

-------- SAMs -------

'@


#Invoke Add-SamSite for all subobjects of the sam parent object.
$samObj.psobject.Properties |  ForEach-Object -Process{ Add-SamSite -sam $_ -iadsName $iadsName }


# Activate IADS and end file
Add-Content $OutFile @"

$iadsName`:setupSAMSitesAndThenActivate()

end

"@
