using Module ./acli_base.psm1

class azmetric: acli_base{
    get_vmsize($location){
        if($this.input_data.rg.Length -eq 0){
            Write_oh("Parameter is still not set.")
            common_exit 1
        }
        $size_list = az vm list-sizes --resource-group $this.input_data.rg --location $location
    }

}