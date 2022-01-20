# �p�r�FAzureCli�𗘗p����vm�T�C�Y�ύX���s���܂�
# azcli_mod_psm1�Ɠ������Ďg�p���܂�
# ���s�p�̃X�N���v�g��execute.ps1�Ȃ̂Ŏ��ۂ̎g�p���@�͂������������������


# ��{���W���[���̃C���|�[�g
using module ./scripts/azcli_mod.psm1
. ./scripts/azchappgw.ps1

class chvmsize: azmod {
    chvmsize_aroundappgw([String]$size,[String]$appgw,[int]$flag){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.vms.Length -eq 0)){
            Write_OH("�p�����[�^�[��ݒ肵�Ă�������")
            exit_common 1
        }
        if($this.input_data.appgw.Length -eq 0){
            Write_OH("�p�����[�^�[��ݒ肵�Ă�������")
            exit_common 1
        }
        $appgw_instance = New-Object chappgw
        $appgw_instance.set_appgw($this.input_data.appgw,$this.input_data.rg)
        foreach($name in $this.input_data.vms){
            if($name.Length -ne 0){
                $vminfo = az vm show -g $this.input_data.rg -n $name | ConvertFrom-Json
                $currentsize = $vminfo.hardwareProfile.vmSize
                if($size -eq $currentsize){
                    Write_OH("$name �͂��ł� $size �ł��B")
                }else{
                    $ipaddresses = @()
                    foreach($onedata in $vminfo.networkProfile.networkInterfaces.id){
                        $tmp_data =  az resource show --ids $onedata | ConvertFrom-Json
                        $ipaddresses += $tmp_data.properties.ipConfigurations.properties.privateIPAddress
                    }
                    $allhealth = az network application-gateway show-backend-health --resource-group $this.input_data.rg -n $this.input_data.appgw|Select-String """Address"":"
                    $vmipcount = 0
                    foreach($tmp in $ipaddresses){
                        $vmipcount += [int]($allhealth|Select-string $tmp).Count
                    }
                    $appgw_instance.go_around_ip_from_pool($name,"remove")
                    # health check
                    $health = $False
                    while($health -eq $False){
                        $healthchecks = az network application-gateway show-backend-health --resource-group $this.input_data.rg -n $this.input_data.appgw|Select-String """Address"":"
                        if(([int]$healthcheck.Count + $vmipcount) -eq [int]$allhealth.Count){
                            $health = $True
                        }
                        sleep(2)
                    }
                    az vm resize --resource-group $this.input_data.rg --name $name --size $
                    $appgw_instance.go_around_ip_from_pool($name,"add")
                    # health check
                    $health = $False
                    while($health -eq $False){
                        $healthchecks = az network application-gateway show-backend-health --resource-group $this.input_data.rg -n $this.input_data.appgw|Select-String """Address"":"
                        if([int]$healthcheck.Count -eq [int]$allhealth.Count){
                            $health = $True
                        }
                        sleep(2)
                    }
                }
            }
        }
        Write_OH("�������������܂���")
    }
    exec_remote_vm($name,$command){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.vms.Length -eq 0)){
            Write_OH("�p�����[�^�[��ݒ肵�Ă�������")
            exit_common 1
        }
        az vm run-command invoke -g $this.input_data.rg -n $name --command-id RunShellScript --scripts "uname -n"
        if($? -eq $False){
            Write_OH("���L�R�}���h�̏����Ɏ��s���܂���")
            Write_OH($command)
            exit_common 1
        }
        Write_OH("�������������܂���")
    }
}
