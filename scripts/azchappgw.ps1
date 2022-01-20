# 用途：AzureCliを利用してappgwのサイズ変更・VM切り離しを行います
# azcli_mod_psm1と同梱して使用します
# 実行用のスクリプトはexecute.ps1なので実際の使用方法はそちらをご覧ください

# Reference 
# https://docs.microsoft.com/ja-jp/cli/azure/network/nic?view=azure-cli-latest

# 基本モジュールのインポート
using module ./scripts/azcli_mod.psm1

class chappgw: azmod {
    # SKUサイズ変更用
    ch_size([int]$capacity,[String]$size){
        # セットされたデータ外の場合はじく
        if($this.input_data.appgw.Length -eq 0){
            Write_OH("アプリケーションゲートウェイ名が変数input_dataに設定されていません")
            exit_common 1
        }
        $name = $this.input_data.appgw
        if($name.Length -ne 0){
            # 現在のデータ取得・入力値との比較
            $appgw_data = az network application-Gateway show --name $name --resource-group $this.input_data.rg | ConvertFrom-Json
            Write_OH("AppGWname: $name Capacity: $($appgw_data.sku.capacity) Size: $($appgw_data.sku.name)")
            $size_list = @("Standard_Large", "Standard_Medium", "Standard_Small", "Standard_v2", "WAF_Large", "WAF_Medium", "WAF_v2")
            if($size_list.IndexOf($size) -eq -1){
                Write_OH("指定サイズが誤っております。以下のサイズから選択ください:   $size_list")
                exit_common 1
            }
            if(
                ($capacity -eq $appgw_data.sku.capacity) -and
                ($size -eq $appgw_data.sku.name)
            ){
                Write_OH("This AppGW has been set yet")
            }else{
                # サイズ変更
                Write_OH("Change this AppGW / Capacity: $capacity SizeTier: $size ")
                az network application-Gateway update --name $name --resource-group $this.input_data.rg --set sku.capacity=$capacity --sku $size
                if($? -eq $False){
                    Write_OH("処理失敗. Please Check the bellow status")
                    $appgw_data = az network application-Gateway show --name $name --resource-group $this.input_data.rg | ConvertFrom-Json
                    Write_OH("Current Status: $name Capacity: $($appgw_data.sku.capacity) Size: $($appgw_data.sku.name)")
                    exit_common 1
                }else{
                    Write_OH("Process Successed. Please Check the bellow status")
                    $appgw_data = az network application-Gateway show --name $name --resource-group $this.input_data.rg | ConvertFrom-Json
                    Write_OH("Current Status: $name Capacity: $($appgw_data.sku.capacity) Size: $($appgw_data.sku.name)")
                }
            }
        }
    }

    # AppGW切り離し・切り戻し（新規追加）用
    go_around_ip_from_pool([String]$vmnames,[String]$action){
        # 引数チェック
        if(($action -ne "remove") -and ($action -ne "add")){
            Write_OH("第二引数に指定した値が誤っています。 (remove / add)")
            exit_common 1
        }
        if($this.input_data.appgw.Length -eq 0){
            Write_OH("アプリケーションゲートウェイ名が変数input_dataに設定されていません")
            exit_common 1
        }
        $name = $this.input_data.appgw
        $appgw_iplist = "$($this.input_data.output)\appgw_ip_list_$($this.input_data.rg)_$name.json"
        $org_bep_status =  (az network application-gateway show --resource-group $this.input_data.rg --name $name | convertfrom-json).backendAddressPools
        if((test-Path $appgw_iplist) -eq $False){
            if($action -eq "remove"){
                az network application-gateway show --resource-group $this.input_data.rg --name $name > $appgw_iplist
            }else{
                Write-Output("All") > $appgw_iplist
            }
        }
        try{
            $bep_memo = (Get-content $appgw_iplist | ConvertFrom-Json).backendAddressPools
        }catch{
            $bep_memo = Get-content $appgw_iplist
        }
        # 切り離しの関数宣言
        $function_remove_ip = {
            param (
                [String]$vmip,
                [String]$name,
                [String]$rg,
                [String]$poolname
            )
            $tmp_info = az network application-gateway address-pool show --gateway-name $name --resource-group $rg -n $poolname | ConvertFrom-Json
            # Write-Output("az network application-gateway address-pool update --remove backendAddresses $($tmp_info.backendAddresses.ipAddress.IndexOf($vmip)) --gateway-name $name --resource-group $rg -n $poolname") >> "C:\temp\result.text"
            az network application-gateway address-pool update --remove backendAddresses $($tmp_info.backendAddresses.ipAddress.IndexOf($vmip)) --gateway-name $name --resource-group $rg -n $poolname
        }
        # 接続時の関数宣言
        $function_add_ip = {
            param (
                [String]$vmip,
                [String]$name,
                [String]$rg,
                [String]$poolname
            )
            # Write-Output("az network application-gateway address-pool update --add backendAddresses ipAddress=$vmip --gateway-name $name --resource-group $rg -n $poolname") >> "C:\temp\result.text"
            az network application-gateway address-pool update --add backendAddresses ipAddress=$vmip --gateway-name $name --resource-group $rg -n $poolname
        }
        foreach($vmname in $vmnames.split(",")){
            # ipアドレスの取得
            $vmnicids = (az vm show -g $this.input_data.rg -n $vmname | ConvertFrom-Json).networkProfile.networkInterfaces.id
            $vmips = foreach($oneid in $vmnicids){(az resource show --ids $oneid | ConvertFrom-Json).properties.ipConfigurations.properties.privateIPAddress}
            # バックエンドプールの取得
            $pool_list = az network application-gateway address-pool list --gateway-name $name --resource-group $this.input_data.rg | ConvertFrom-Json
            
            # poolの数だけ切り離し実行
            foreach($pool in $pool_list){
                # 事前情報取得の書き出し
                Write_OH("Prior info/ BackendPoolName: $($pool.name) Ipaddress: $($pool.backendAddresses.ipAddress) ")
                foreach($vmip in $vmips){
                    # VMのIPアドレスが存在する場合は切り離しする
                    try{
                        if($action -eq "remove"){
                            if($pool.backendAddresses.ipAddress.IndexOf($vmip) -eq -1){
                                continue
                            }
                        }else{
                            if($bep_memo -ne "All"){
                                if(($bep_memo|?{$_.name -eq $pool.name}).backendAddresses.ipAddress.IndexOf($vmip) -eq -1){
                                    continue
                                }
                            }
                        }
                        # コマンドをバックグラウンドから投げる
                        Write_OH("------------------------------------------")
                        Write_OH("[run $action] : $vmip BEP: $($pool.name)")
                        Write_OH("------------------------------------------")
                        if($action -eq "remove"){
                            $jobA = Start-Job -ScriptBlock $function_remove_ip -ArgumentList $vmip,$name,$($this.input_data.rg),$($pool.name)
                        }else{
                            $jobA = Start-Job -ScriptBlock $function_add_ip -ArgumentList $vmip,$name,$this.input_data.rg,$pool.name
                        }
                        $diff_result = 0
                        $retry = 0
                        While(($diff_result.Length -le 1) -and ($retry -lt 10)){
                            $new_bep_status =  (az network application-gateway show --resource-group $this.input_data.rg --name $name | convertfrom-json).backendAddressPools
                            $diff_result = compare-Object $new_bep_status $org_bep_status -Property ipAddress
                            Write_OH("現在のBEP設定")
                            $nuw_status = $new_bep_status|?{$_.name -eq $pool.name}
                            Write_OH("BEP name: $($nuw_status.name)")
                            Write_OH("IpAddress : $($nuw_status.backendAddresses.ipAddress)")
                            sleep 10
                            $retry += 1
                            if($retry -eq 7){
                                Write_OH("コマンドを再実行しますか？(y/n)")
                                $yn = Read-Host(">>")
                                if($yn[0] -eq "y"){
                                    if($action -eq "remove"){
                                        $jobA = Start-Job -ScriptBlock $function_remove_ip -ArgumentList $vmip,$name,$($this.input_data.rg),$($pool.name)
                                    }else{
                                        $jobA = Start-Job -ScriptBlock $function_add_ip -ArgumentList $vmip,$name,$this.input_data.rg,$pool.name
                                    }
                                }
                            }elseif($retry -eq 9){
                                Write_OH("90秒以上経過しました。次の処理のから選んでください")
                                Write_OH("1.処理の中断")
                                Write_OH("2.待機続行")
                                Write_OH("3.次の処理へ移る")
                                $num_flag = Read-Host(">>")
                                if($num_flag -eq "1"){
                                    Write_OH("処理を中断します")
                                    exit_common 1
                                }if($num_flag -eq "2"){
                                    Write_OH("待機続行します")
                                    $retry = 0
                                }if($num_flag -eq "3"){
                                    Write_OH("次の処理へ移ります")
                                    break
                                }
                            }
                        }
                    }catch{
                        Write_OH("BEPになし : $vmip BEP: $($pool.name)")
                    }
                    $org_bep_status =  (az network application-gateway show --resource-group $this.input_data.rg --name $name | convertfrom-json).backendAddressPools
                }
            }
        }
        $pool_list = az network application-gateway address-pool list --gateway-name $name --resource-group $this.input_data.rg | ConvertFrom-Json
        Write_OH("処理結果-----------------------------------------")
        foreach($pool in $pool_list){
            # 事後情報取得の書き出し
            Write_OH("Posterior info/ BackendPoolName: $($pool.name) Ipaddress: $($pool.backendAddresses.ipAddress) ")
        }
        Write_OH("処理完了")
    }

    # 特定FQDNに関するAppgw上の設定参照
    [System.Object]showSettingAboutFQDN($fqdn){
        $appgw_info = az network application-gateway show --resource-group $this.input_data.rg --name $this.input_data.appgw
        Write-Output($appgw_info) > "$($this.input_data.output)/$($this.input_data.appgw)_$(Get-Date -Format "yyyyMMddhhmmss").json"
        $appgw_info = $appgw_info | ConvertFrom-json
        Write_OH("以下はアプリケーションゲートウェイ内に含まれる設定です")
        Write_OH("------------------------------------------------------------")
        # 対象の情報を収集
        # backendAddressPools
        Write_OH("<backendAddressPools>")
        Write_OH($appgw_info.backendAddressPools.name)
        Write_OH("-以下は対象id")
        $backendAddressPools = $appgw_info.backendAddressPools.name | Where-Object{$_.Contains($fqdn)}
        foreach($bname in $backendAddressPools){
            Write_OH((az network application-gateway address-pool show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $bname | ConvertFrom-json).id)
        }
        # backendHttpSettingsCollection
        Write_OH("<backendHttpSettingsCollection>")
        Write_OH($appgw_info.backendHttpSettingsCollection.name)
        Write_OH("-以下は対象id")
        $backendHttpSettingsCollection = $appgw_info.backendHttpSettingsCollection.name | Where-Object{$_.Contains($fqdn)}
        foreach($bhname in $backendHttpSettingsCollection){
            Write_OH((az network application-gateway http-settings show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $bhname | ConvertFrom-json).id)
        }
        # httpListeners
        Write_OH("<httpListeners>")
        Write_OH($appgw_info.httpListeners.name)
        Write_OH("-以下は対象id")
        $httpListeners = $appgw_info.httpListeners.name | Where-Object{$_.Contains($fqdn)}
        foreach($hlname in $httpListeners){
            Write_OH((az network application-gateway http-listener show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $hlname | ConvertFrom-json).id)
        }
        # probes
        Write_OH("<probes>")
        Write_OH($appgw_info.probes.name)
        Write_OH("-以下は対象id")
        $probes = $appgw_info.probes.name | Where-Object{$_.Contains($fqdn)}
        foreach($pname in $probes){
            Write_OH((az network application-gateway probe show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $pname | ConvertFrom-json).id)
        }
        # requestRoutingRules
        Write_OH("<requestRoutingRules>")
        Write_OH($appgw_info.requestRoutingRules.name)
        Write_OH("-以下は対象id")
        $requestRoutingRules = $appgw_info.requestRoutingRules.name | Where-Object{$_.Contains($fqdn)}
        foreach($rrrname in $requestRoutingRules){
            Write_OH((az network application-gateway rule show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $rrrname | ConvertFrom-json).id)
        }
        # sslCertificates
        Write_OH("<sslCertificates>")
        Write_OH($appgw_info.sslCertificates.name)
        Write_OH("-以下は対象id")
        try{
            $sslCertificates = $appgw_info.sslCertificates.name | Where-Object{$_.Contains($fqdn)}
            foreach($scname in $sslCertificates){
                (az network application-gateway ssl-cert show --resource-group $this.input_data.rg --gateway-name $this.input_data.appgw --name $scname | ConvertFrom-json)
            }
        }catch{

        }
        return $appgw_info
    }

    # 特定FQDNに関する設定の削除
    removeSettingAboutFQDN($fqdn){
        if(($this.input_data.rg.Length -eq 0) -or ($this.input_data.appgw.Length -eq 0)){
            Write_OH('変数が設定されていません')
            exit_common 1
        }
        # backgroundjobの設定
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
        $select = Read-Host("削除を実施していいですか？(y/n)")
        if($select[0] -eq "y"){
            # 削除実施
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
            Write_OH("処理完了")
            Write_OH("事後情報確認")
            $appgw_info = $this.showSettingAboutFQDN($fqdn)
        }else{
            Write_OH("処理はキャンセルされました")
        }
    }

    compare_2obj($obj1,$obj2){
        if(($obj1.Length -eq 0) -and ($obj2.Length -eq 0)){
            Write_OH("比較対象がありません")
            return
        }
        if(($obj1.Length -eq 0) -and ($obj2.Length -ne 0)){
            Write_OH("APGW2にのみ設定あり")
            Write_OH("以下追加設定内容")
            foreach($onedata in $obj2){
                $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                foreach($mem in $info_name){
                    Write_OH("$mem")
                    Write_OH("$($onedata.($mem))")
                }
            }
        }elseif(($obj1.Length -ne 0) -and ($obj2.Length -eq 0)){
            Write_OH("<<<<APGW1にのみ設定あり>>>")
            Write_OH("以下追加設定内容")
            foreach($onedata in $obj1){
                $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                foreach($mem in $info_name){
                    Write_OH("-----------------------------$mem")
                    Write_OH("$($onedata.($mem))")
                }
            }
        }else{
            # 差分比較
            foreach($onedata in $obj1){
                if($obj2.name.IndexOf($onedata.name) -ne -1){
                    # 同一名の設定が存在する場合
                    $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                    foreach($mem in $info_name){
                        if(($mem -ne $null) -and ($mem.Length -ne 0)){
                            Write_OH("<<<差分比較>>>")
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
                    Write_OH("<<<APGW1 にのみ存在>>>")
                    $info_name = ($onedata | Get-member | Where-Object{$_.MemberType -ne "Method"}).name
                    foreach($mem in $info_name){
                        Write_OH("-----------------------------$mem")
                        Write_OH("$($onedata.($mem))")
                    }
                }
            }
            foreach($onedata in $obj2){
                if($obj1.name.IndexOf($onedata.name) -eq -1){
                    Write_OH("<<<APGW2 にのみ存在>>>")
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
            Write_OH("パラメーターが設定されていません。")
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

