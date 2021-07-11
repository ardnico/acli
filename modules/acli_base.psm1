
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
        if($resource_type_list.Length -eq 0){
            Write_oh("the resource group name looks like wrong name.please review the name.")
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
            if($this.input_data.rg.Length -eq 0){
                $this.input_data.Add("rg",$resourcegroupname)
            }
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
    set_rg([String]$resourcegroupname){
        $keyname = "rg"
        $type = "Microsoft.Network/applicationGateways"
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add("rg",$resourcegroupname)
        }else{
            Write_oh("Resource group name will be updated: $($this.input_data.rg) to $($resourcegroupname)")
            $this.input_data.rg = $resourcegroupname
        }
    }
    set_output([String]$output){
        $this.input_data.output = $output
    }

    azlogin($env){
        $account = az account show | ConvertFrom-Json
        if($? -eq $False){
            # az login method
            az login
        }
        $this.input_data.Add("env",$env)
        $this.input_data.Add("output","output")
    }

    azsplogin($env){
        $account = az account show | ConvertFrom-Json
        if($? -eq $False){
            New-Item -ItemType Directory -Force "credential"
            $pass_file = ".\credential\say_peace.pw"
            $id_file = ".\credential\plat.on"
            # login method
            if((Test-Path $pass_file -eq $False) -or (Test-Path $id_file -eq $False)){
                $AzCred = New-Object System.Management.Automation.PSCredential $(Get-Content $id_file), (Get-Content $pass_file | ConvertTo-SecureString )
                if($? -eq $False){
                    $AzCred = ""
                }
            }else{
                $AzCred = ""
            }
            if($AzCred -eq ""){
                Write_oh("the information 'id' and 'password' isn't set still")
                Write_oh("please input the credential information of the principal service account")
                $AzCred = Get-Credential
                $AzCred.UserName | Set-Content $id_file
                $AzCred.Password | ConvertFrom-SecureString | Set-Content $pass_file
            }
            az login --service-principal --username $AzCred.UserName --tenant $env --password $AzCred.GetNetworkCredential().Password
            if($? -eq $False){
                Write_oh("Login action has failed.Sorry review the parameter, or remove the credential file and try to login")
                common_exit 1
            }
        }
        $this.input_data.Add("env",$env)
        $this.input_data.Add("output","output")
    }
}