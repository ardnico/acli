# 更新履歴
# 2021/07/15 Ver 1.0 release
# 　実装機能　：　Appgwサイズ変更,AppGWからのVM切り離し・接続,VM・AppGWメトリックデータの取得
# 　実装予定　：　VMサイズ変更,各種リソース削除,AppGW設定追加,メトリックデータと連携してVMサイズ変更(VM作成,AppGW※作成権限の関係で優先度低)


# CSVデータ取得
$csvdata = Get-Content ".\Parameter.csv" | ConvertFrom-Csv
$logfile = "output\az_$(Get-Date -Format "yyyyMMddhhmmss").log"
New-Item -Force -ItemType Directory "output"
Start-transcript $logfile


foreach($onedata in $csvdata){
    $rg = $onedata.ResourceGroupName
    if($onedata.Action.Contains("AppGW")){
        # AppGW変更
        . ./scripts/azchappgw.ps1
        $az_instance = New-Object chappgw
        $az_instance.azlogin($onedata.Env)
        $az_instance.set_appgw([String]$onedata.Target,[String]$rg)
        if($onedata.Action -eq "chAppGWsize"){
            # アプリケーションゲートウェイの構成サイズ変更
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
            Write_OH("未設定のアクションです")
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
            Write_OH("未設定のアクションです")
        }
    }else{
        Write_OH("未設定のアクションです")
    }
}
Stop-transcript