
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

    # set varaiables
    set_resources(
        [String]$resources,
        [String]$resourcegroupname,
        [String]$keyname
        [String]$type
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
        foreach($name in $resources.split(",")){
            $reference_test = az resource show -g $resourcegroupname -n $name
            if($? -eq $False){
                Write_oh("please review the parameter")
                common_exit 1
            }
        }
        # set parameter
        $this.input_data.Add($keyname,$resources.split(","))
    }

    set_resource(
        [String]$resource,
        [String]$resourcegroupname,
        [String]$keyname
        [String]$type
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
        $reference_test = az resource show -g $resourcegroupname -n $resource
        if($? -eq $False){
            Write_oh("please review the parameter")
            common_exit 1
        }else{
            # set parameter
            $this.input_data.Add($keyname,$resource)
        }
    }

    set_vms([String]$resources, [String]$resourcegroupname){
        $keyname = "vms"
        $type = "Microsoft.Compute/virtualMachines"
        $this.set_resources(
            [String]$resources,
            [String]$resourcegroupname,
            [String]$keyname
            [String]$type
        )
    }

    set_appgw([String]$resource, [String]$resourcegroupname){
        $keyname = "appgw"
        $type = "Microsoft.Network/applicationGateways"
        $this.set_resource(
            [String]$resource,
            [String]$resourcegroupname,
            [String]$keyname
            [String]$type
        )
    }

    azlogin($env){
        $account = az account show | ConvertFrom-Json
        if($? -eq $False){
            # az login method
            az login
        }
        $this.input_data.Add("env",$env)
    }

    azlogin($env){
        $account = az account show | ConvertFrom-Json
        if($? -eq $False){
            New-Item -ItemType Directory -Force "credential"
            $pass_file = ".\"
            # login method
            if(Test-Path )
            $login_files = 
        }
        $this.input_data.Add("env",$env)
    }
}