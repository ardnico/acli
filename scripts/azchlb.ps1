##### �쐬��



# �p�r�FAzureCli�𗘗p����loadbalancer�̃T�C�Y�ύX�EVM�؂藣�����s���܂�
# azcli_mod_psm1�Ɠ������Ďg�p���܂�
# ���s�p�̃X�N���v�g��execute.ps1�Ȃ̂Ŏ��ۂ̎g�p���@�͂������������������

# Reference 
# https://docs.microsoft.com/ja-jp/cli/azure/network/nic?view=azure-cli-latest

# ��{���W���[���̃C���|�[�g
using module ./scripts/azcli_mod.psm1

class chlb: azmod {
    # SKU�T�C�Y�ύX�Ƃ����T�O�͂Ȃ�

    # LB�؂藣���E�؂�߂��i�V�K�ǉ��j�p
    go_around_ip_from_pool([String]$vmnames,[String]$action){
        # �����`�F�b�N
        if(($action -ne "remove") -and ($action -ne "add")){
            Write_OH("�������Ɏw�肵���l������Ă��܂��B (remove / add)")
            exit_common 1
        }
        if($this.input_data.lb.Length -eq 0){
            Write_OH("���[�h�o�����T�����ϐ�input_data�ɐݒ肳��Ă��܂���")
            exit_common 1
        }
        $lb_info = az resource show --resource-group $this.input_data.rg --name $this.input_data.lb --resource-type "Microsoft.Network/loadBalancers" | ConvertFrom-Json
        $bep = $lb_info.properties.backendAddressPools.name

        [int]$hlist_all = $lb_info.properties.backendAddressPools.properties.backendIPConfigurations.id.Count
        [int]$exe_num = 0
        # �؂藣���̊֐��錾
        $function_remove_ip = {
            param (
                [String]$ipname,
                [String]$lb,
                [String]$rg,
                [String]$poolname
            )
            az network lb address-pool address remove -g $rg --lb-name $lb --pool-name $poolname -n $ipname
        }
        # �ڑ����̊֐��錾
        $function_add_ip = {
            param (
                [String]$ipname,
                [String]$lb,
                [String]$rg,
                [String]$poolname,
                [String]$ipadress
            )
            az network lb address-pool address add -g $rg --lb-name $lb --pool-name $poolname -n $ipname --vnet MyVnet --ip-address $ipadress
        }
        $pool_and_ip = @{}
        foreach($vmname in $vmnames.split(",")){
            # ip�A�h���X�̎擾
            $vmnicids = (az vm show -g $this.input_data.rg -n $vmname | ConvertFrom-Json).networkProfile.networkInterfaces.id
            $vmips = foreach($oneid in $vmnicids){(az resource show --ids $oneid | ConvertFrom-Json).properties.ipConfigurations.properties.privateIPAddress}
            # �o�b�N�G���h�v�[���̎擾
            foreach($vmip in $vmips){$pool_and_ip.Add($vmip,"")}
            $pool_list = az network application-gateway address-pool list --gateway-name $name --resource-group $this.input_data.rg | ConvertFrom-Json
            # pool�̐������؂藣�����s
            foreach($pool in $pool_list){
                # ���O���擾�̏����o��
                Write_OH("Prior info/ BackendPoolName: $($pool.name) Ipaddress: $($pool.backendAddresses.ipAddress) ")
                if($action -eq "remove"){
                    foreach($vmip in $vmips){
                        # VM��IP�A�h���X�����݂���ꍇ�͐؂藣������
                        if($pool.backendAddresses.ipAddress.IndexOf($vmip) -ne -1){
                            # �؂藣���R�}���h���T�T���Ɠ�����
                            Write_OH("�؂藣�����s : $vmip BEP: $($pool.name)")
                            $jobA = Start-Job -ScriptBlock $function_remove_ip -ArgumentList $vmip,$name,$($this.input_data.rg),$($pool.name)
                            $exe_num += 1
                            # �؂藣����IP�A�h���X�ƃo�b�N�G���h�v�[���������t�@�C���ɒǋL
                            if($pool_and_ip.($vmip).Length -gt 0){$pool_and_ip.($vmip) += ","}
                            $pool_and_ip.($vmip) += [String]$pool.name
                        }
                    }
                }elseif($action -eq "add"){
                    # �؂藣�����̈ꎞ�ۑ��f�[�^�̓ǂݎ�聦���݂��Ȃ��ꍇ�͂��̂܂ܑSBackendPool�ɒǉ�����
                    if(Test-Path "$($this.input_data.output)/$($vmname)_poolinfo.json"){
                        $priorpoolinfo = Get-Content "$($this.input_data.output)/$($vmname)_poolinfo.json" | ConvertFrom-Json
                    }else{
                        $priorpoolinfo = @{}
                    }
                    # �ꎞ�ۑ��f�[�^�Ƀo�b�N�G���h�v�[�������Ȃ���΁AIP�A�h���X�͒ǉ����Ȃ�
                    foreach($vmip in $vmips){
                        if($priorpoolinfo.Count -ne 0){
                            $tmp_line_array = $priorpoolinfo.($vmip).split(",")
                        }else{
                            $tmp_line_array = $pool_list.name
                        }
                        Write_OH($tmp_line_array)
                        Write_OH("vmip: $vmip")
                        Write_OH($pool.name)
                        if($tmp_line_array.Length -gt 0){
                            # �S�䓊���p
                            if($tmp_line_array.($vmip).Length -eq 0){
                                if($tmp_line_array.IndexOf($pool.name) -ne -1){
                                    Write_OH("�ڑ����s : $vmip BEP: $($pool.name)")
                                    $jobA = Start-Job -ScriptBlock $function_add_ip -ArgumentList $vmip,$name,$this.input_data.rg,$pool.name
                                    $exe_num += 1
                                }
                            }else{
                                # �����t�@�C�����Q�l��IP�A�h���X��AppGW�֒ǉ�
                                if($tmp_line_array.($vmip).IndexOf($pool.name) -ne -1){
                                    Write_OH("�ڑ� : $vmip BEP: $($pool.name)")
                                    $jobA = Start-Job -ScriptBlock $function_add_ip -ArgumentList $vmip,$name,$this.input_data.rg,$pool.name
                                    $exe_num += 1
                                }
                            }
                        }
                    }
                }
            }
            if($action -eq "remove"){
                $pool_and_ip | ConvertTo-Json > "$($this.input_data.output)/$($vmname)_poolinfo.json"
            }
        }
        $border_num = 1
        $err_num = 0
        while($err_num -lt $border_num+1){
            if($err_num -gt $border_num -1){
                Write_OH("99�b�ȏ�o�߂��܂����B �����𑱍s���܂����H")
                $judge = Read-Host("y/n")
                if($judge[0] -eq "y"){
                    $err_num += 500
                }else{
                    exit_common 1
                }
            }else{
                Start-sleep 3
                $health_list = az network application-gateway show-backend-health --resource-group $this.input_data.rg --name $this.input_data.appgw | Select-String '"address":'
                $hnum = $health_list.Length
                if($action -eq "remove"){
                    if($($hnum + $exe_num) -eq $hlist_all){
                        $err_num += 500
                    }
                }elseif($action -eq "add"){
                    if($($exe_num + $hlist_all) -eq $hnum){
                        $err_num += 500
                    }
                }else{
                    $err_num += 500
                }
                $err_num += 1
            }
        }
        $pool_list = az network application-gateway address-pool list --gateway-name $name --resource-group $this.input_data.rg | ConvertFrom-Json
        foreach($pool in $pool_list){
            # ������擾�̏����o��
            Write_OH("Posterior info/ BackendPoolName: $($pool.name) Ipaddress: $($pool.backendAddresses.ipAddress) ")
        }
        Write_OH("��������")
    }

    # ����FQDN�Ɋւ���Appgw��̐ݒ�Q��
    [System.Object]showSettingAboutFQDN($fqdn){
        $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
        Write-Output($appgw_info) > "$($this.input_data.output)/$($this.input_data.appgw)_$(Get-Date -Format "yyyyMMddhhmmss").json"
        $appgw_info = $appgw_info | ConvertFrom-json
        Write_OH("�ȉ��̓A�v���P�[�V�����Q�[�g�E�F�C���Ɋ܂܂��ݒ�ł�")
        Write_OH("------------------------------------------------------------")
        # �Ώۂ̏������W
        # backendAddressPools
        Write_OH("<backendAddressPools>")
        Write_OH($appgw_info.backendAddressPools.name)
        Write_OH("-�ȉ��͑Ώ�id")
        $backendAddressPools = $appgw_info.backendAddressPools.name | Where-Object{$_.Contains($fqdn)}
        foreach($bname in $backendAddressPools){
            Write_OH((az network application-gateway address-pool show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $bname | ConvertFrom-json).id)
        }
        # backendHttpSettingsCollection
        Write_OH("<backendHttpSettingsCollection>")
        Write_OH($appgw_info.backendHttpSettingsCollection.name)
        Write_OH("-�ȉ��͑Ώ�id")
        $backendHttpSettingsCollection = $appgw_info.backendHttpSettingsCollection.name | Where-Object{$_.Contains($fqdn)}
        foreach($bhname in $backendHttpSettingsCollection){
            Write_OH((az network application-gateway http-settings show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $bhname | ConvertFrom-json).id)
        }
        # httpListeners
        Write_OH("<httpListeners>")
        Write_OH($appgw_info.httpListeners.name)
        Write_OH("-�ȉ��͑Ώ�id")
        $httpListeners = $appgw_info.httpListeners.name | Where-Object{$_.Contains($fqdn)}
        foreach($hlname in $httpListeners){
            Write_OH((az network application-gateway http-listener show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $hlname | ConvertFrom-json).id)
        }
        # probes
        Write_OH("<probes>")
        Write_OH($appgw_info.probes.name)
        Write_OH("-�ȉ��͑Ώ�id")
        $probes = $appgw_info.probes.name | Where-Object{$_.Contains($fqdn)}
        foreach($pname in $probes){
            Write_OH((az network application-gateway probe show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $pname | ConvertFrom-json).id)
        }
        # requestRoutingRules
        Write_OH("<requestRoutingRules>")
        Write_OH($appgw_info.requestRoutingRules.name)
        Write_OH("-�ȉ��͑Ώ�id")
        $requestRoutingRules = $appgw_info.requestRoutingRules.name | Where-Object{$_.Contains($fqdn)}
        foreach($rrrname in $requestRoutingRules){
            Write_OH((az network application-gateway rule show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $rrrname | ConvertFrom-json).id)
        }
        # sslCertificates
        Write_OH("<sslCertificates>")
        Write_OH($appgw_info.sslCertificates.name)
        Write_OH("-�ȉ��͑Ώ�id")
        try{
            $sslCertificates = $appgw_info.sslCertificates.name | Where-Object{$_.Contains($fqdn)}
            foreach($scname in $sslCertificates){
                (az network application-gateway ssl-cert show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $scname | ConvertFrom-json)
            }
        }catch{

        }
        return $appgw_info
    }

    # ����FQDN�Ɋւ���ݒ�̍폜
    removeSettingAboutFQDN($fqdn){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.appgw.Length -eq 0)){
            Write_OH('�ϐ����ݒ肳��Ă��܂���')
            exit_common 1
        }
        # backgroundjob�̐ݒ�
        $function_rm_probe = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$pname
            )
            if($pname.Length -ne 0){
                az network application-gateway probe delete --resource-group $rg --gateway-name $appgw --name $pname
            }
        }
        $function_rm_rrr = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$rrrname
            )
            if($rrrname.Length -ne 0){
               az network application-gateway rule delete --resource-group $rg --gateway-name $appgw --name $rrrname
            }
        }
        $function_rm_hl = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$hlname
            )
            if($hlname.Length -ne 0){
                az network application-gateway http-listener delete --resource-group $rg --gateway-name $appgw --name $hlname
            }
        }
        $function_rm_b = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$bname
            )
            if($bname.Length -ne 0){
                az network application-gateway address-pool delete --resource-group $rg --gateway-name $appgw --name $bname
            }
        }
        $function_rm_bh = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$bhname
            )
            if($bhname.Length -ne 0){
                az network application-gateway http-settings delete --resource-group $rg --gateway-name $appgw --name $bhname
            }
        }
        $function_rm_sc = {
            param (
                [String]$rg,
                [String]$appgw,
                [String]$scname
            )
            if($scname.Length -ne 0){
                az network application-gateway ssl-cert delete --resource-group $rg --gateway-name $appgw --name $scname
            }
        }

        $appgw_info = $this.showSettingAboutFQDN($fqdn)
        $select = Read-Host("�폜�����{���Ă����ł����H(y/n)")
        if($select[0] -eq "y"){
            # �폜���{
            # probes
            Write_OH("probes")
            $probes = $appgw_info.probes.name | Where-Object{$_.Contains($fqdn)}
            foreach($pname in $probes){
                $jobA = Start-Job -ScriptBlock $function_rm_probe -ArgumentList $this.input_data.rg,$this.input_data.appgw,$pname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $probes = $appgw_info.probes.name | Where-Object{$_.Contains($fqdn)}
                    if($probes.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($probes|Where-Object{$_ -eq $pname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            # requestRoutingRules
            Write_OH("requestRoutingRules")
            $requestRoutingRules = $appgw_info.requestRoutingRules.name | Where-Object{$_.Contains($fqdn)}
            foreach($rrrname in $requestRoutingRules){
                $jobB = Start-Job -ScriptBlock $function_rm_rrr -ArgumentList $this.input_data.rg,$this.input_data.appgw,$rrrname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $requestRoutingRules = $appgw_info.requestRoutingRules.name | Where-Object{$_.Contains($fqdn)}
                    if($requestRoutingRules.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($requestRoutingRules|Where-Object{$_ -eq $rrrname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            # httpListeners
            Write_OH("httpListeners")
            $httpListeners = $appgw_info.httpListeners.name | Where-Object{$_.Contains($fqdn)}
            foreach($hlname in $httpListeners){
                $jobC = Start-Job -ScriptBlock $function_rm_hl -ArgumentList $this.input_data.rg,$this.input_data.appgw,$hlname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $httpListeners = $appgw_info.httpListeners.name | Where-Object{$_.Contains($fqdn)}
                    if($httpListeners.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($httpListeners|Where-Object{$_ -eq $hlname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            # backendAddressPools
            Write_OH("backendAddressPools")
            $backendAddressPools = $appgw_info.backendAddressPools.name | Where-Object{$_.Contains($fqdn)}
            foreach($bname in $backendAddressPools){
                $jobD = Start-Job -ScriptBlock $function_rm_b -ArgumentList $this.input_data.rg,$this.input_data.appgw,$bname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $backendAddressPools = $appgw_info.backendAddressPools.name | Where-Object{$_.Contains($fqdn)}
                    if($backendAddressPools.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($backendAddressPools|Where-Object{$_ -eq $bname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            # backendHttpSettingsCollection
            Write_OH("backendHttpSettingsCollection")
            $backendHttpSettingsCollection = $appgw_info.backendHttpSettingsCollection.name | Where-Object{$_.Contains($fqdn)}
            foreach($bhname in $backendHttpSettingsCollection){
                $jobE = Start-Job -ScriptBlock $function_rm_bh -ArgumentList $this.input_data.rg,$this.input_data.appgw,$bhname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $backendHttpSettingsCollection = $appgw_info.backendHttpSettingsCollection.name | Where-Object{$_.Contains($fqdn)}
                    if($backendHttpSettingsCollection.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($backendHttpSettingsCollection|Where-Object{$_ -eq $bhname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            
            # sslCertificates
            Write_OH("sslCertificates")
            $sslCertificates = $appgw_info.sslCertificates.name | Where-Object{$_.Contains($fqdn)}
            foreach($scname in $sslCertificates){
                $jobF = Start-Job -ScriptBlock $function_rm_sc -ArgumentList $this.input_data.rg,$this.input_data.appgw,$scname
                $escape_loop = 0
                While($escape_loop -eq 0){
                    sleep(3)
                    $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
                    $sslCertificates = $appgw_info.sslCertificates.name | Where-Object{$_.Contains($fqdn)}
                    if($sslCertificates.Count -eq 0){
                        $escape_loop = 1
                    }elseif($($sslCertificates|Where-Object{$_ -eq $scname}).Count -eq 0){
                        $escape_loop = 1
                    }
                }
            }
            Write_OH("��������")
            Write_OH("������m�F")
            $appgw_info = $this.showSettingAboutFQDN($fqdn)
        }else{
            Write_OH("�����̓L�����Z������܂���")
        }
    }

    compare_2obj($obj1,$obj2){
        if(($obj1.Length -eq 0) -and ($obj2.Length -eq 0)){
            Write_OH("��r�Ώۂ�����܂���")
            return
        }
        if(($obj1.Length -eq 0) -and ($obj2.Length -ne 0)){
            Write_OH("APGW2�ɂ̂ݐݒ肠��")
            Write_OH("�ȉ��ǉ��ݒ���e")
            foreach($onedata in $obj2){
                $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                foreach($mem in $info_name){
                    Write_OH("$mem")
                    Write_OH("$($onedata.($mem))")
                }
            }
        }elseif(($obj1.Length -ne 0) -and ($obj2.Length -eq 0)){
            Write_OH("<<<<APGW1�ɂ̂ݐݒ肠��>>>")
            Write_OH("�ȉ��ǉ��ݒ���e")
            foreach($onedata in $obj1){
                $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                foreach($mem in $info_name){
                    Write_OH("-----------------------------$mem")
                    Write_OH("$($onedata.($mem))")
                }
            }
        }else{
            # ������r
            foreach($onedata in $obj1){
                if($obj2.name.IndexOf($onedata.name) -ne -1){
                    # ���ꖼ�̐ݒ肪���݂���ꍇ
                    $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                    foreach($mem in $info_name){
                        if(($mem -ne $null) -and ($mem.Length -ne 0)){
                            Write_OH("<<<������r>>>")
                            Write_OH("-----------------------------$mem")
                            if(($($obj1.($mem)) -ne $null) -and ($($obj2.($mem)) -ne $null)){
                                try{
                                    $result = Compare-Object $obj1.($mem) $obj2.($mem)
                                    if($result.Length -gt 0){
                                        foreach($diff in $result){
                                            Write_OH("$($diff.InputObject)  $($diff.SideIndicator)")
                                        }
                                    }
                                }catch{
                                    Write_OH("$($obj1.($mem)) /  $($obj2.($mem))")
                                }
                            }else{
                                Write_OH("-----------------------------$mem")
                                if($($obj1.($mem)) -eq $null){
                                    Write_OH("[$($obj2.name)]")
                                }elseif($($obj2.($mem)) -eq $null){
                                    Write_OH("[$($obj1.name)]")
                                }
                                Write_OH("$($obj1.($mem)) $($obj2.($mem))")
                            }
                        }
                    }
                }else{
                    Write_OH("<<<APGW1 �ɂ̂ݑ���>>>")
                    $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                    foreach($mem in $info_name){
                        Write_OH("-----------------------------$mem")
                        Write_OH("$($onedata.($mem))")
                    }
                }
            }
            foreach($onedata in $obj2){
                if($obj1.name.IndexOf($onedata.name) -eq -1){
                    Write_OH("<<<APGW2 �ɂ̂ݑ���>>>")
                    $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                    foreach($mem in $info_name){
                        Write_OH("-----------------------------$mem")
                        Write_OH("$($onedata.($mem))")
                    }
                }
            }
        }

    }

    diff_Appgw([String]$appgw1,[String]$appgw2,[String]$rg,[String]$fqdn){
        if(($appgw1.Length -eq 0) -or ($appgw2.Length -eq 0)){
            Write_OH("�p�����[�^�[���ݒ肳��Ă��܂���B")
            exit_common 1
        }
        $appgw1_data = az network application-gateway show --resource-group $rg --name $appgw1 | ConvertFrom-Json
        $appgw2_data = az network application-gateway show --resource-group $rg --name $appgw2 | ConvertFrom-Json
        Write_OH("Difference------------------")
        Write_OH("<backendAddressPools>")
        $tmp_obj1 = $appgw1_data.backendAddressPools|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.backendAddressPools|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
        Write_OH("<backendHttpSettingsCollection>")
        $tmp_obj1 = $appgw1_data.backendHttpSettingsCollection|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.backendHttpSettingsCollection|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
        Write_OH("<httpListeners>")
        $tmp_obj1 = $appgw1_data.httpListeners|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.httpListeners|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
        Write_OH("<probes>")
        $tmp_obj1 = $appgw1_data.probes|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.probes|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
        Write_OH("<requestRoutingRules>")
        $tmp_obj1 = $appgw1_data.requestRoutingRules|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.requestRoutingRules|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
        Write_OH("<sslCertificates>")
        $tmp_obj1 = $appgw1_data.sslCertificates|Where-Object{$_.name.Contains($fqdn)}
        $tmp_obj2 = $appgw2_data.sslCertificates|Where-Object{$_.name.Contains($fqdn)}
        $this.compare_2obj($tmp_obj1,$tmp_obj2)
    }

}

