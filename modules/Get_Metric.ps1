using Module ./acli_base.psm1

class azmetric: acli_base{
    get_vmsize(){
        $size_list = az vm list-sizes --resource-group 
    }
}