
function Write_oh([String]$line){
    $key = "$(Get-Date -Format "[yyyy/MM/dd hh:mm:ss]") $line"
    Write-Host($key)
    Write-Output($key)
    return $key
}

function common_exit($code){
    
}

class acli_base{
    [System.Object]$global:input_data = @{}

    set_param(
        [String]$resourcegroupname,
        [String]$resources,
        [String]$type
    ){
        # Check the parameter
        $resource_type_list = az 
    }
}