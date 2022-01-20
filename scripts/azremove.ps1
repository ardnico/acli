##### �쐬��




# �p�r�FAzureCli�𗘗p���ă��\�[�X�폜���s���܂��B�ݒ�ύX�͕ʃ��W���[���Ŏ��{��������
# azcli_mod_psm1�Ɠ������Ďg�p���܂�
# ���s�p�̃X�N���v�g��execute.ps1�Ȃ̂Ŏ��ۂ̎g�p���@�͂������������������


# ��{���W���[���̃C���|�[�g
using module ./scripts/azcli_mod.psm1

class azremove: azmod {
    # RG�̍폜�p���\�b�h
    goodbye_rg([int]$force){

    }
    # ���\�[�X�폜�p���\�b�h
    goodbye_resources([Array]$resources,[int]$force){
        if($this.input_data.rg.Length -eq 0)){
            Write_OH("�p�����[�^�[��ݒ肵�Ă�������")
            exit_common 1
        }
        $all_resource_list = (az resource list | Convertfrom-Json)
        # �폜�Ώۃ��\�[�X���Q��
        foreach($resource in $resources){
            $target_id = ($all_resource_list|Where-Object{$_.name -eq $resource}).id
            Write_OH("[$($resource) ID]: $target_id")
        # Json�����o��
            $json_file_name = "$($this.input_data.output)\$($resource)_$(get-Date -format "yyyymmdd").json"
            az resource show --ids $target_id > $json_file_name
            $resource_info = (az resource show --ids $target_id|Convertfrom-json)
            switch($resouce_info.type){
                Microsoft.Compute/virtualMachines{
                    $nic_ids =  $resouce_info.properties.networkProfile.networkInterfaces.id
                    $disk_ids = $resouce_info.properties.storageProfile.osDisk.managedDisk.id
                    $ddisk_ids = $resouce_info.properties.storageProfile.dataDisks.managedDisk.id
                    Write_OH("[�֘ANIC]")
                    foreach($nic_id in $nic_ids){Write_OH($nic_id)}
                    Write_OH("[�֘AOsDisk]")
                    foreach($disk_id in $disk_ids){Write_OH($disk_id)}
                    Write_OH("[�֘ADataDisk]")
                    foreach($ddisk_id in $ddisk_ids){Write_OH($ddisk_id)}
                }
                default{}
            }
        }
        # �ŏI�m�F
        if($force -gt 0){
            $flag = Read-Hsot("�{���ɍ폜���܂����H(y/n):")
        }
        if($flag -eq "y"){
            foreach($resource in $resources){
                $target_id = ($all_resource_list|Where-Object{$_.name -eq $resource}).id
                $resouce_info = az resource show --ids $target_id | Convertfrom-json
                switch($resouce_info.type){
                    # �p���Z�b�g�̏ꍇ
                    Microsoft.Compute/availabilitySets{
                        if($resouce_info.properties.virtualMachines.id.Count -gt 0){
                            $Write_OH("�p���Z�b�g����VM�����݂��邽�ߏ����𒆒f���܂�")
                            $Write_OH("[�Ώۉp���Z�b�g��]: $resource")
                            exit_common 1
                        }else{
                            az vm availability-set delete --ids $target_id --debug --verbose
                        }
                    }
                    Microsoft.Compute/disks{
                        az disk delete --ids $target_id --yes --no-wait
                    }
                    Microsoft.Compute/snapshots{
                        az snapshot delete --ids $target_id 
                    }
                    Microsoft.Compute/virtualMachines{
                        $nic_ids =  $resouce_info.properties.networkProfile.networkInterfaces.id
                        $disk_ids = $resouce_info.properties.storageProfile.osDisk.managedDisk.id
                        $ddisk_ids = $resouce_info.properties.storageProfile.dataDisks.managedDisk.id
                        # ���蓖�ĉ���
                        az vm stop --ids $target_id --no-wait 
                        az vm deallocate --ids $target_id --no-wait
                        az vm delete --ids $target_id --yes --no-wait
                        
                        $disk_name| ForEach-Object {az disk delete --ids $_ --yes --no-wait}
                        $ddisk_name| ForEach-Object {az disk delete --ids $_ --yes --no-wait}
                        $nic_names| ForEach-Object{az network nic delete --ids $_ --no-wait}
                    }
                    Microsoft.Network/applicationGateways{
                        # az network application-gateway probe delete --ids  --no-wait
                        # az network application-gateway rule delete --ids   --no-wait
                        
                        (Get-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW).Name | ForEach-Object{Remove-AzureRmApplicationGatewayBackendHttpSettings -ApplicationGateway $AppGW -Name $_}
                        (Get-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $AppGW).Name | ForEach-Object{Remove-AzureRmApplicationGatewayProbeConfig -ApplicationGateway $AppGW -Name $_}
                        (Get-AzureRmApplicationGatewayHttpListener -ApplicationGateway $AppGW).Name | ForEach-Object{Remove-AzureRmApplicationGatewayHttpListener -ApplicationGateway $AppGW -Name $_}
                        Remove-AzureRmApplicationGateway -Name $Name -ResourceGroupName $ResourceGroupName -Force
                    }
                    # Microsoft.Network/loadBalancers{
                    #     $BL = Get-AzureRmLoadBalancer -Name $Name -ResourceGroupName $ResourceGroupName
                    #     (Get-AzureRmLoadBalancerInboundNatPoolConfig -LoadBalancer $BL).Name | ForEach-Object{Remove-AzureRmLoadBalancerInboundNatPoolConfig -LoadBalancer $BL -Name $_}
                    #     (Get-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $BL).Name | ForEach-Object{Remove-AzureRmLoadBalancerInboundNatRuleConfig -LoadBalancer $BL -Name $_}
                    #     (Get-AzureRmLoadBalancerOutboundRuleConfig -LoadBalancer $BL).Name | ForEach-Object{Remove-AzureRmLoadBalancerOutboundRuleConfig -LoadBalancer $BL -Name $_}
                    #     (Get-AzureRmLoadBalancerRuleConfig -LoadBalancer $BL).Name | ForEach-Object{Remove-AzureRmLoadBalancerRuleConfig -LoadBalancer $BL -Name $_}
                    #     (Get-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $BL).Name | ForEach-Object{Remove-AzureRmLoadBalancerBackendAddressPoolConfig -LoadBalancer $BL -Name $_}
                    #     Remove-Remove-AzureRmLoadBalancer -Name $Name -ResourceGroupName $ResourceGroupName -Force
                    #     }
                    # Microsoft.Network/networkInterfaces{
                    #     Remove-AzureRmNetworkInterface -ResourceGroupName $ResourceGroupName -Name $Name -force
                    # }
                    # Microsoft.Network/networkSecurityGroups{
                    #     Remove-AzureRmNetworkSecurityGroup -ResourceGroupName $ResourceGroupName -Name $Name -force
                    # }
                    # Microsoft.Network/publicIPAddressses{
                    #     Remove-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroupName -Name $Name -force
                    # }
                    # Microsoft.Sql/servers{
                    #     $Sdata = Get-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -Name $Name
                    #     Get-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $Sdata.ServerName | Foreach-Object{
                    #         if($_.DatabaseName -ne "master"){
                    #             Remove-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $_.ServerName -DatabaseName $_.DatabaseName -Force
                    #         }
                    #     }
                    #     Remove-AzureRmSqlServer -ResourceGroupName $ResourceGroupName -ServerName $Sdata.ServerName -Force
                    # }
                    # Microsoft.Sql/servers/databases{
                    #     Remove-AzureRmSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $Name.split("/")[0] -DatabaseName $Name.split("/")[1] -Force
                    # }
                    # Microsoft.Storage/storageAccounts{
                    #     Remove-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $Name -Force
                    # }
                    # Microsoft.Web/sites{
                    #     $WebApp = Get-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $Name
                    #     foreach($data in $WebApp.SlotSwapStatus){
                    #         Stop-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $Name -Slot $data.SourceSlotName -Force
                    #     }
                    #     Stop-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $Name -Force
                    #     foreach($data in $WebApp.SlotSwapStatus){
                    #         Remove-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $Name -Slot $data.SourceSlotName -Force
                    #     }
                    #     Remove-AzureRmWebApp -ResourceGroupName $ResourceGroupName -Name $Name -Force
                    # }
                    # Microsoft.Web/sites/slots{
                    #     Stop-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $Name.split("/")[0] -Slot $Name.split("/")[1] -Force
                    #     Remove-AzureRmWebAppSlot -ResourceGroupName $ResourceGroupName -Name $Name.split("/")[0] -Slot $Name.split("/")[1] -Force
                    # }
                    default{
                        $this.Write_OH("����`�̃��\�[�X�̂��ߍ폜�ł��܂���")
                    }
                    # Microsoft.Compute/galleries
                    # Microsoft.Compute/images
                    # microsoft.alertsmanagement/smartDetectorAlertRules{}
                    # Microsoft.Compute/galleries/images{}
                    # Microsoft.Compute/galleries/images/versions{}
                    # Microsoft.insights/components{}
                    # Microsoft.insights/metricalerts{}
                    # Microsoft.Compute/restorePointCollections{}
                    # Microsoft.Web/certificates{}
                    # Microsoft.Web/serverFarms{}
                    # Microsoft.Compute/virtualMachines/extensions{}
                    # Microsoft.DevTestLab/schedules{}
                    # Microsoft.SqlVirtualMachine/SqlVirtualMachines{}
                    # Microsoft.Portal/dashboards{}

                }
            }
        }else{
            Write_OH("�����𒆒f���܂���")
            exit_common 1
        }
        # �폜������̃��\�[�X��\��
        $all_resource_list_after = (az resource list | Convertfrom-Json)
        Write_OH("[�폜���ꂽ���\�[�X�ꗗ]")
        Compare-Object $all_resource_list_after $all_resource_list_after|Foreach-Object{Write_OH("$($_.InputObject)  $($_.SideIndicator)")}
    }
}

# 2. yes no �̑I��(force�@�\����)
