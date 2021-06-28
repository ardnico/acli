
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
        [String]$keyname
        [String]$type,
        [int]$flag # 1: Multiple resources 2: single resource
    ){
        # Check the parameter
        [Array]$resource_type_list = (az resource list -g $resourcegroupname | ConvertFrom-Json).type
        if($? -eq $False){
            Write_oh("The resourcegroup name likes mistaken : $resourcegroupname")
            common_exit 1
        }
        if($resource_type_list.IndexOf($type) -eq -1){
            Write_oh("There is no such type resource $type")
            common_exit 1
        }
        if($flag -eq 1){
            $reference_test = az resource show -g $resourcegroupname -n $resources
            if($? -eq $False){
                Write_oh("please review the parameter")
                common_exit 1
            }else{
                input_data.Add($keyname,$resources)
            }
        }elseif($flag -eq 2){
            foreach($name in $resources.split(",")){
                $reference_test = az resource show -g $resourcegroupname -n $name
                if($? -eq $False){
                    Write_oh("please review the parameter")
                    common_exit 1
                }
            }
            input_data.Add($keyname,$resources.split(","))
        }else{
            Write_oh("Sorry, please select the number '1' or '2' at the 5th potision.")
            common_exit 1
        }
    }
}