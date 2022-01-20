# �X�V����
# 2021/07/15 Ver 1.0 release
# �@�����@�\�@�F�@Appgw�T�C�Y�ύX,AppGW�����VM�؂藣���E�ڑ�,VM�EAppGW���g���b�N�f�[�^�̎擾
# �@�����\��@�F�@VM�T�C�Y�ύX,�e�탊�\�[�X�폜,AppGW�ݒ�ǉ�,���g���b�N�f�[�^�ƘA�g����VM�T�C�Y�ύX(VM�쐬,AppGW���쐬�����̊֌W�ŗD��x��)


# CSV�f�[�^�擾
$csvdata = Get-Content ".\Parameter.csv" | ConvertFrom-Csv
$logfile = "output\az_$(Get-Date -Format "yyyyMMddhhmmss").log"
New-Item -Force -ItemType Directory "output"
Start-transcript $logfile


foreach($onedata in $csvdata){
    $rg = $onedata.ResourceGroupName
    if($onedata.Action.Contains("AppGW")){
        # AppGW�ύX
        . ./scripts/azchappgw.ps1
        $az_instance = New-Object chappgw
        $az_instance.azlogin($onedata.Env)
        $az_instance.set_appgw([String]$onedata.Target,[String]$rg)
        if($onedata.Action -eq "chAppGWsize"){
            # �A�v���P�[�V�����Q�[�g�E�F�C�̍\���T�C�Y�ύX
            $az_instance.ch_size([int]$onedata.Param1,[String]$onedata.Param2)
        }elseif($onedata.Action -eq "isolatefromAppGW"){
            $az_instance.go_around_ip_from_pool([String]$onedata.Param1,"remove")
        }elseif($onedata.Action -eq "mergeintoAppGW"){
            $az_instance.go_around_ip_from_pool([String]$onedata.Param1,"add")
        }elseif($onedata.Action -eq "deleteSettingsFromAppGW"){
            $fqdn = $onedata.Param1
            $az_instance.removeSettingAboutFQDN($fqdn)
        }elseif($onedata.Action -eq "ddiffAppGW"){
            $az_instance.diff_Appgw([String]$onedata.Target,[String]$onedata.Param1,[String]$rg,[String]$onedata.Param2)
        }else{
            Write_OH("���ݒ�̃A�N�V�����ł�")
        }
    }elseif($onedata.Action.Contains("GetPerf")){
        . ./scripts/Get-perf.ps1
        $Exec_gp = New-Object GetMetric
        $Exec_gp.azlogin($onedata.Env)
        if($onedata.Action -eq "GetPerfVMS"){
            $vms = $onedata.Target
            $rg = $onedata.ResourceGroupName
            $start_date = $onedata.Param1
            $end_date = $onedata.Param2
            $Exec_gp.set_vms([String]$vms,[String]$rg)
            $Exec_gp.get_vm_metric($start_date,$end_date)
        }elseif($onedata.Action -eq "GetPerfVMSCurrent"){
            $vms = $onedata.Target
            $rg = $onedata.ResourceGroupName
            $Exec_gp.set_vms([String]$vms,[String]$rg)
            $Exec_gp.get_current_vm_metric()
        }elseif($onedata.Action -eq "GetPerfAppgw"){
            $appgw = $onedata.Target
            $rg = $onedata.ResourceGroupName
            $start_date = $onedata.Param1
            $end_date = $onedata.Param2
            $Exec_gp.set_appgw([String]$appgw,[String]$rg)
            $csv = $Exec_gp.get_appgw_metric($start_date,$end_date)
        }elseif($onedata.Action -eq "GetPerfAppgwCurrent"){
            $appgw = $onedata.Target
            $rg = $onedata.ResourceGroupName
            $Exec_gp.set_appgw([String]$appgw,[String]$rg)
            $return_array = $Exec_gp.get_current_appgw_metric()
            Write_OH($return_array)
        }elseif($onedata.Action -eq "GetPerfVMsize"){
            $Exec_gp.set_rg([String]$rg)
            $Exec_gp.get_size_list()
        }elseif($onedata.Action -eq "GetPerfVMactivity"){
            $vms = $onedata.Target
            $rg = $onedata.ResourceGroupName
            $Exec_gp.set_rg([String]$rg)
            foreach($vmname in $vms){
                $Exec_gp.get_activity_log($vmname)
            }
        }else{
            Write_OH("���ݒ�̃A�N�V�����ł�")
        }
    }else{
        Write_OH("���ݒ�̃A�N�V�����ł�")
    }
}
Stop-transcript