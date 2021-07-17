using Module ./acli_base.psm1

class azvm : acli_base{
    chappgwsize($capacity,$size){
        if(($this.input_data.rg.Length -eq 0) -and ($this.input_data.appgw.Length -eq 0)){
            Write_oh("Parameter isn't still set")
            common_exit 1
        }
        $appgw = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw | ConvertFrom-Json
        if(($appgw.sku.capacity -eq $capacity) -and ($appgw.sku.size -eq $size)){
            Write_oh("This appgw has already changed.")
        }else{
            az network application-gateway update --resource-group $this.input_data.rg --name $this.input_data.appgw --capacity $capacity --sku  $size
            if($? -eq $False){
                Write_oh("Failed to change the size of the application gateway")
                common_exit 1
            }
        }
    }
    goaroundVM($vm,$action){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.env.Length -eq 0)){
            Write_oh("Parameter is still not set")
            common_exit 1
        }
        $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $name | ConvertFrom-Json
        $function_remove = {
            param (
                [String]$MyResourceGroup,
                [String]$MyAppGateway,
                [String]$MyAddressPool,
                [String]vmip
            )
            $tmp_info = az network application-gateway address-pool show -g $MyResourceGroup --gateway-name $MyAppGateway -n $MyAddressPool |ConvertFrom-Json
            az network application-gateway address-pool update -g $MyResourceGroup --gateway-name $MyAppGateway -n $MyAddressPool --remove backendAddresses $tmp_info.backendaddresspool.ipaddress.IndexOf($vmip)
        }
        if($action -eq "add"){

        }elseif($action -eq "remove"){
            $poollist = az network | ConvertFrom-Json
            foreach($pool in $poollist){
            $jobA = Start-Job -ScriptBlock $function_remove -ArgumentList $this.input_data.rg,$this.input_data.appgw,$pool.name,$vmip
            }
        }

    }
    
}