using Module ./acli_base.psm1

class azvm : acli_base{
    chappgwsize($){
        if(($this.input_data.rg.Length -eq 0) -and ($this.input_data.appgw.Length -eq 0)){
            Write_oh("Parameter isn't still set")
            common_exit 1
        }
        $appgw = az network application-gateway show -g $this.input_data.rg -n $this.input_data.appgw | ConvertFrom-Json
    }

}