add-type -path ".\Microsoft.Z3.dll"

# import raw VM data and convert strings to ints
$sourceVMs = Import-Csv .\vmdata.csv
$sourceVMs  | % { $_.cpu = [int]$_.cpu; $_.ram = [int]$_.ram; $_.datadisk = [int]$_.datadisk; }

$targetSizes = import-csv ".\vmCostACUData.csv"

## hash tables with data to simplify search
$sourceVmHt = @{}
$targetVmHt = @{}

$sourceVMs | % {
    $sourceVmHt[$_.vmID] = $_
}

$targetSizes | % {
    $targetVmHt[$_.Name] = $_
}
##

$ctx = [Microsoft.Z3.Context]::new()
$zero = $ctx.MkNumeral(0, $ctx.MkIntSort())
$one = $ctx.MkNumeral(1, $ctx.MkIntSort())

# enum existingVMs;
# enum vmSizes;

$existingVMs = $ctx.MkEnumSort("existingVMs", $sourceVMs.vmid)
$vmSizes = $ctx.MkEnumSort("vmSizes", $targetSizes.Name)


$selectedSize = 
    $sourceVMs | % {
        $ctx.MkConst($_.vmid, $vmSizes)
    }


$s = $ctx.MkSolver()


# constraint forall(vm in existingVMs)(
#    vmSizeCPU[selectedSize[vm]] >=  vmCPU[vm]
# );


## assuming $_.ToString() returns the name of the variable
## and $_ it's value
$selectedSize | % {
    $a = $ctx.MkNumeral($sourceVmHt[$_.ToString()].cpu, $ctx.MkIntSort())
    $b = $ctx.MkNumeral($targetVmHt[$_].vCPUs, $ctx.MkIntSort())
    $s.Add( $ctx.MkGt($a, $b))
}

# constraint forall(vm in existingVMs)(
#     vmSizeRAM[selectedSize[vm]] >= vmRAM[vm]
# );

$selectedSize | % {
    $a = $ctx.MkNumeral($sourceVmHt[$_.ToString()].ram, $ctx.MkIntSort())
    $b = $ctx.MkNumeral($targetVmHt[$_].MemoryGB, $ctx.MkIntSort())
    $s.Add( $ctx.MkGt($a, $b))
}

$s.Check()
$m = $s.Model

$m.Decls