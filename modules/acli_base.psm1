
function Write_oh([String]$line){
    $key = "$(Get-Date -Format "[yyyy/MM/dd hh:mm:ss]") $line"
    Write-Host($key)
    Write-Output($key)
    return $key
}

function common_exit($code){
    if($code -eq 0){
        Write_oh("Process successed")
    }else{
        Write_oh("Abortion occured")
        exit $code
    }
}

class acli_base{
    [System.Object]$global:input_data = @{}

    set_param(
        [String]$resourcegroupname,
        [String]$resources,
        [String]$type
    ){
        # Check the parameter
        [Array]$resource_type_list = (az resource list).type
        if($resource_type_list.IndexOf($type) -eq -1){
            Write_oh("")
        }
    }
}