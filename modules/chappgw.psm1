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
            
        }
    }


}