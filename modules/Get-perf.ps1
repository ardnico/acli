

# Param(
#     [parameter(mandatory=$true)][String]$ResourceGroupName,
#     [parameter(mandatory=$true)][array]$Name,
#     [parameter(mandatory=$true)][String]$env,
#     [parameter(mandatory=$true)][String]$start_date, # "2021/06/04 00:00:00"
#     [parameter(mandatory=$true)][String]$end_date,
#     [parameter(mandatory=$true)][Int]$species # 1:VM 2:APGW
# )

# class Azcli{
#     Login($env){
#         if ((az account list | ConvertFrom-Json).Count -eq 0){
#             az login
#         }
#         Write-host("change subscription environment")
#         az account set --subscription $env
#     }
# }

using module ./scripts/azcli_mod.psm1

class GetMetric : azmod{
    [Array]ExCSV($name,$start_date,$end_date,[int]$species ){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.env.Length -eq 0)){
            Write_OH("parameter が設定されていません")
            exit_common 1
        }
        [Array]$return_array = @()
        if(($species -gt 2) -or ($species -lt 1)){
            Write-Output("speciesの指定の仕方が誤っています");
            Write-Output("次の数字を入力してください 1:VM 2:AppGW");
        }
        # 日付加工
        $date_list = @()
        $tmp_start = [DateTime]::ParseExact($start_date,"yyyy/MM/dd hh:mm:ss", $null);
        if($tmp_start -lt (Get-Date).AddDays(-93)){
            Write-Host("指定された開始日が古すぎます");
            $tmp_start = (Get-Date).AddDays(-93)
        }
        $tmp_end = [DateTime]::ParseExact($end_date,"yyyy/MM/dd HH:mm:ss", $null);
        while ($tmp_start -le $tmp_end){
            $tmp_pre = ($tmp_start).AddDays(1)
            if($tmp_pre -le $tmp_end){
                $tmp_str = $(($tmp_start).ToString("yyyy-MM-ddTHH:mm:ssZ") + "_" + ($tmp_pre).ToString("yyyy-MM-ddTHH:mm:ssZ"))
                $date_list += $tmp_str
            }elseif($tmp_start -eq $tmp_end){

            }elseif($tmp_pre -gt $tmp_end){
                $tmp_str = $(($tmp_start).ToString("yyyy-MM-ddTHH:mm:ssZ") + "_" + ($tmp_end).ToString("yyyy-MM-ddTHH:mm:ssZ"))
                $date_list += $tmp_str
            }
            $tmp_start = $tmp_pre
        }
        # データ取得
        $outputPath = "$($this.input_data.output)\$($name)cpu_percentage_$((Get-Date).ToString("yyyyMMddhhmmss")).csv"
        $return_array += $outputPath
        if($species -eq 1){
            $id = (az vm show --resource-group $this.input_data.rg --name $name|ConvertFrom-Json).id
            if($id.Length -eq 0){
                az login
                az account set --subscription $this.input_data.env
                $id = (az vm show --resource-group $this.input_data.rg --name $name|ConvertFrom-Json).id
            }
            $p = "average,count,maximum,minimum,timeStamp,total"
            $p | Out-File -Encoding default -FilePath $outputPath
            Foreach($date_string in $date_list){
                $s_date = $date_string.split("_")[0]
                $e_date = $date_string.split("_")[1]
                # VM の場合の情報取得 CPU使用率のみ
                $tmp_metricDtata = az monitor metrics list --resource $id --metric "Percentage CPU" --start-time $s_date --end-time $e_date|ConvertFrom-Json
                $line = $tmp_metricDtata.value.timeseries.data
                for ( $index = 0; $index -lt $line.count; $index++){                
                    $p = [String]$line.average[$index]+"," + [String]$line.count[$index] + "," +  [String]$line.maximum[$index] + "," + [String]$line.minimum[$index] + "," + [String]$line.timeStamp[$index] + "," + [String]$line.total[$index]
                    $p | Add-Content -Encoding default $outputPath
                }
            }
        }elseif($species -eq 2){
            $outputPath_cu = "$($this.input_data.output)\$($Name)CPUUtilization_$(Get-Date -Format "yyyyMMddhhmmss").csv"
            $outputPath_fr = "$($this.input_data.output)\$($Name)FailedRequests_$(Get-Date -Format "yyyyMMddhhmmss").csv"
            $outputPath_tr = "$($this.input_data.output)\$($Name)TotalRequests_$(Get-Date -Format "yyyyMMddhhmmss").csv"
            $return_array += $outputPath_cu
            $return_array += $outputPath_fr
            $return_array += $outputPath_tr
            $p = "average,count,maximum,minimum,timeStamp,total"
            $p | Out-File -Encoding default -FilePath $outputPath_cu
            $p | Out-File -Encoding default -FilePath $outputPath_fr
            $p | Out-File -Encoding default -FilePath $outputPath_tr            
            $id = (az resource show --resource-group $this.input_data.rg --name $name --resource-type "Microsoft.Network/applicationgateways"|ConvertFrom-Json).id
            Foreach($date_string in $date_list){
                $s_date = $date_string.split("_")[0]
                $e_date = $date_string.split("_")[1]
                $tmp_metricDtata = az monitor metrics list --resource $id --metric "CPUUtilization" --start-time $s_date --end-time $e_date|ConvertFrom-Json
                $line = $tmp_metricDtata.value.timeseries.data
                for ( $index = 0; $index -lt $line.count; $index++){ 
                    $p = [String]$line.average[$index]+"," + [String]$line.count[$index] + "," +  [String]$line.maximum[$index] + "," + [String]$line.minimum[$index] + "," + [String]$line.timeStamp[$index] + "," + [String]$line.total[$index]
                    $p | Add-Content -Encoding default $outputPath_cu
                }
                $tmp_metricDtata = az monitor metrics list --resource $id --metric "FailedRequests" --start-time $s_date --end-time $e_date|ConvertFrom-Json
                $line = $tmp_metricDtata.value.timeseries.data
                for ( $index = 0; $index -lt $line.count; $index++){ 
                    $p = [String]$line.average[$index]+"," + [String]$line.count[$index] + "," +  [String]$line.maximum[$index] + "," + [String]$line.minimum[$index] + "," + [String]$line.timeStamp[$index] + "," + [String]$line.total[$index]
                    $p | Add-Content -Encoding default $outputPath_fr
                }
                $tmp_metricDtata = az monitor metrics list --resource $id --metric "TotalRequests" --start-time $s_date --end-time $e_date|ConvertFrom-Json
                $line = $tmp_metricDtata.value.timeseries.data
                for ( $index = 0; $index -lt $line.count; $index++){ 
                    $p = [String]$line.average[$index]+"," + [String]$line.count[$index] + "," +  [String]$line.maximum[$index] + "," + [String]$line.minimum[$index] + "," + [String]$line.timeStamp[$index] + "," + [String]$line.total[$index]
                    $p | Add-Content -Encoding default $outputPath_tr
                }
            }
        }
        return $return_array
    }

    [Array]get_vm_metric($start_date,$end_date){
        if($this.input_data.vms.Length -eq 0){
            Write_OH("parameter が設定されていません")
            exit_common 1
        }
        [Array]$return_array = @()
        foreach($Name in $this.input_data.resources){
            [Array]$result_path = $this.ExCSV( $Name,$start_date,$end_date,1)
            $return_array += $result_path[0]
        }
        return $return_array
    }

    [Array]get_appgw_metric($start_date,$end_date){
        [Array]$return_array = @()
        [Array]$result_path = $this.ExCSV( $this.input_data.appgw,$start_date,$end_date,2 )
        $return_array += $result_path[0]
        $return_array += $result_path[1]
        $return_array += $result_path[2]
        return $return_array
    }

    [Array]get_current_vm_metric(){
        $start_date = [String](Get-Date).AddMinutes(-5).ToString("yyyy/MM/dd hh:mm:ss")
        $end_date = [String](Get-Date -Format "yyyy/MM/dd hh:mm:ss")
        $return_array = $this.get_vm_metric($start_date,$end_date)
        return $return_array
    }

    [Array]get_current_appgw_metric(){
        $start_date = [String](Get-Date).AddMinutes(-5).ToString("yyyy/MM/dd hh:mm:ss")
        $end_date = [String](Get-Date -Format "yyyy/MM/dd hh:mm:ss")
        $return_array = $this.get_appgw_metric($start_date,$end_date)
        return $return_array
    }

    get_activity_log($vmname){
        Write_OH("アクティビティログを取得します")
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.env.Length -eq 0)){
            Write_OH("parameter が設定されていません")
            exit_common 1
        }
        $rlist = az resource list --resource-group $this.input_data.rg | Convertfrom-Json
        $target_id = ""
        foreach($oneline in $rlist){
            if($oneline.name -eq $vmname){
                $target_id = $oneline.id
                break
            }
        }
        if($target_id.Length -eq 0){
            Write_OH("対象が見つけられませんでした。$($this.input_data.rg)/$($vmname)")
            exit_common 1
        }
        $startlist = az monitor activity-log list --query "[?operationName.value=='Microsoft.Compute/virtualMachines/start/action']" --offset 90d --resource-id $target_id | ConvertFrom-Json
        $tmp_csv_data = @()
        foreach($oneline in $startlist) {
            $tmp_csv_data += [pscustomobject]@{
                Action = "Start";
                Date = $(Get-Date $oneline.submissionTimestamp -Format "yyyy/MM/dd HH:mm:ss");
                Status = $oneline.status.value;
            }
        }

        $deallocatelist = (az monitor activity-log list --query "[?operationName.value=='Microsoft.Compute/virtualMachines/deallocate/action']" --offset 90d --resource-id $target_id |ConvertFrom-Json)
        foreach($oneline in $deallocatelist){
            $tmp_csv_data += [pscustomobject]@{
                Action="Deallocate";
                Date=$(Get-Date $oneline.submissionTimestamp -Format "yyyy/MM/dd HH:mm:ss");
                Status=$oneline.status.value;
            }
        }
        Write_OH("CSV: $($this.input_data.output)\$($vmname)_activity_log_$(get-date -Format "yyyyMMdd").csv")
        $tmp_csv_data | Sort-Object Date -Desc | export-csv "$($this.input_data.output)\$($vmname)_activity_log_$(get-date -Format "yyyyMMdd").csv"
    }

    get_size_list(){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.env.Length -eq 0)){
            Write_OH("パラメーターが設定されていません")
            exit_common 1
        }
        $ldata = @()
        $size_list = az vm list-sizes -l japaneast | ConvertFrom-Json
        $csv_name = "$($this.input_data.output)\$($this.input_data.rg)_size_list.csv"
        $vms = az vm list --resource-group $this.input_data.rg | ConvertFrom-Json
        $num = 1
        Foreach($vmdata in $vms){
            $ldata += New-Object psobject -Property @{
                index = $num
                vmName = $vmdata.name
                SizeName = $vmdata.hardwareProfile.vmSize
                numberOfCores = $($size_list | Where-Object{$_.name -eq $vmdata.hardwareProfile.vmSize}).numberOfCores
                memoryInMb = $($size_list | Where-Object{$_.name -eq $vmdata.hardwareProfile.vmSize}).memoryInMb
            }
            $num += 1
        }
        $ldata |Select-Object -Property index,vmName,SizeName,numberOfCores,memoryInMb | Export-csv $csv_name
        Write_OH("処理が完了しました。")
    }
}