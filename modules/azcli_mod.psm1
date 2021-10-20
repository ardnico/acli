
# 用途：AzureCliを利用したps1スクリプト操作の元となるモジュールです。
# これ単体でもログインに使用できます
# 実行用のスクリプトはexecute.ps1なので実際の使用方法はそちらをご覧ください


# 基本往査に関するクラスはここに記載
# 以下のように継承してクラスを編集して使用ください


# using module ./azcli_mod.psm1

# class ClassName : azmod{
    # test(){
    #     if(error){
    #         exit_common 1
    #     }
    # }
# }


# 使用例
# . ./extendClass.ps1

# $classInstance = New-Object extendClass
# $rg = "Dev-RG-TEST-001"
# $resources = "tesfr901v"
# $type = "Microsoft.Compute/virtualMachines"
# $classInstance.set_resource($rg,$resources,$type)

# $env = "研究"
# $classInstance.azlogin($env)



$Error.Clear()
$global:DefaultErrorActionPreference=[String]$ErrorActionPreference
$ErrorActionPreference="Continue"

# 出力に関する関数
function Write_OH($arg1){
    $line = "$(Get-Date -Format "[yyyy/MM/dd HH:mm:ss]") $arg1"
    Write-Host($line)
    Write-Output($line)
    return
}

# 終了処理
function exit_common($arg1){
    #正常終了時
    if ($arg1 -eq 0 ) {
        Write_OH("プログラムは正常終了しました") 
    #異常終了時
    }else{
        Write_OH("プログラムは処理を中断しました") 
    }
    $ErrorActionPreference=$DefaultErrorActionPreference
    exit $arg1
}


class azmod{
    $global:input_data = @{}

    # 変数格納用
    set_resources([String]$rg,[String]$resources,[String]$keyname,[String]$type){
        $rlist = (az resource list --resource-group $rg | ConvertFrom-Json)
        if($? -eq $False){
            Write_OH("リソースグループの指定が誤っています") 
            exit_common 1
        }
        if($rlist.Length -eq 0){
            Write_OH("リソースグループの指定が誤っています") 
            exit_common 1
        }
        if(($rlist.type | sort | Get-Unique | Where-Object{$_ -eq $type}).Count -eq 0){
            Write_OH("typeの指定が間違えています")
            Write_OH("入力データ: $type")
            Write_OH("下記一覧を参考に指定しなおしてください \n $rlist")
            exit_common 1
        }
        $exit_code = 0
        Write_OH("ResourceGroupName: $rg") 
        foreach($target in $resources.split(',')){
            $target_info = $rlist|Where-Object{$_.name -eq $target}
            Write_OH("Resource Name: $target")  
            if($target_info.name -ne $target){
                Write_OH("存在しないリソース名が指定されています")　
                Write_OH("Value: $($target.name)") 
                $exit_code += 1
            }
            Write_OH("ResourceGroupName: $($target_info.type)") 
            if($target_info.type -ne $type){
                Write_OH("$($target_info.type) 以外のタイプ名が指定されています")
                Write_OH("Value: $type")
                $exit_code += 1
            }
        }
        # 問題がある場合は処理終了
        if($exit_code -gt 0){
            exit_common $exit_code
        }
        # 問題がなければそのまま変数に値を格納
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add( "rg", $rg )
        }
        $this.input_data.Add( $keyname, $resources.split(',') )
    }

    set_resource([String]$rg,[String]$resource,[String]$keyname,[String]$type){
        $rlist = (az resource list --resource-group $rg | ConvertFrom-Json)
        if(($? -eq $False) -or ($rlist.Length -eq 0)){
            Write_OH("リソースグループの指定が誤っています") 
            $exit_code += 1
            exit_common 1
        }
        if(($rlist.type | sort | Get-Unique | Where-Object{$_ -eq $type}).Count -eq 0){
            Write_OH("typeの表記が間違えています")
            Write_OH("入力データ: $type")
            Write_OH("下記一覧を参考に指定しなおしてください")
            Write_OH($rlist.type | sort | Get-Unique)
            exit_common 1
        }
        Write_OH("ResourceGroupName: $rg") 
        $target_info = $rlist|Where-Object{$_.name -eq $resource}
        Write_OH("Resource Name: $resource")  
        if($target_info.name -ne $resource){
            Write_OH("存在しないリソース名が指定されています")　
            Write_OH("Value: $($target_info)") 
            exit_common 1
        }
        Write_OH("Resourcetype: $($target_info.type)") 
        if($target_info.type -ne $type){
            Write_OH("$($target_info.type) 以外のリソースが指定されています")
            Write_OH("Value: $type")
            exit_common 1
        }
        # 問題がなければそのまま変数に値を格納
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add( "rg", $rg )
        }
        $this.input_data.Add( $keyname, $resource )
    }

    # 変数格納用
    set_appgw([String]$appgw,[String]$rg){
        $keyname = "appgw"
        $type = "Microsoft.Network/applicationGateways"
        if($this.input_data.appgw.Length -eq 0){
            $this.set_resource($rg,$appgw,$keyname,$type)
        }elseif($this.input_data.appgw -ne $appgw){
            Write_OH("変数AppGWを $($this.input_data.appgw)　から $appgw へ更新します")
            $this.input_data.appgw = $appgw
        }else{
            Write_OH("変数AppGWは設定済みです")
        }
    }
    set_lb([String]$lb,[String]$rg){
        $keyname = "lb"
        $type = "Microsoft.Network/loadBalancers"
        if($this.input_data.lb.Length -eq 0){
            $this.set_resource($rg,$lb,$keyname,$type)
        }elseif($this.input_data.lb -ne $lb){
            Write_OH("変数lbを $($this.input_data.lb)　から $lb へ更新します")
            $this.input_data.lb = $lb
        }else{
            Write_OH("変数lbは設定済みです")
        }
    }
    set_vms([String]$vms,[String]$rg){
        $keyname = "vms"
        $type = "Microsoft.Compute/virtualMachines"
        $this.set_resources($rg,$vms,$keyname,$type)
    }
    set_rg([String]$rg){
        $keyname = "rg"
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add( "rg", $rg )
        }else{
            Write_OH("ResourceGroup名を$($this.input_data.rg)から$($rg)へ更新します")
            $this.input_data.rg = $rg
        }
    }
    set_output([String]$output){
        $this.input_data.Add( "output", $output )
        New-Item -Force -ItemType Directory $output
    }

    # ログイン用
    azlogin($env){
        try{
            $login_tester = az account list | convertfrom-json
        }catch{
            $login_tester = ""
        }
        if($login_tester.Count -eq 0){
            Write_OH("二要素認証が有効のアカウントではCUIでのログインができません")
            Write_OH("CUIログインを希望する場合は該当RGの権限の付与されたServicePrincipalをご利用ください")
            Write_OH("Webブラウザから手動ログインを実施ください")
            az login
        }
        az account set --subscription $env
        if($? -eq $False){
            az login
            az account set --subscription $env
            if($? -eq $False){
                Write_OH("サブスクリプション環境の指定が誤っています")
                exit_common 1
            }
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }
    azautologin($env){
        # ログインIDとパスの処理
        if(Test-Path "./username"){
            $username = Get-Content "./username"
            $psw = (Get-Content "./psw"  | ConvertTo-SecureString)
            $Credential = New-Object System.Management.Automation.PSCredential $username,$psw
        }else{
            Write-Host("Azureのログイン情報を暗号化して保存します。")
            Write-Host("AzureのログインID(@gintra.bc-glex.net付き)とパスワードを入力してください")
            $Credential = Get-Credential
            $Credential.UserName > "./username"
            $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
            Write-Host("Azureのログイン情報を保存しました。このまま終了します。")
            Exit 0
        }
        az login -u $Credential.UserName -p $Credential.GetNetworkCredential().Password
        if($? -eq $False){
            Write_OH("ログインに失敗しました(二要素認証が有効のアカウントではログインに必ず失敗します)")
            $flag = Read-host("パスワードを変更しましたか？(y/n)")
            if($flag[0] -eq "y"){
                $Credential = Get-Credential -u $Credential.UserName -m "パスワード再設定"
                $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
                az login -u $Credential.UserName -p $Credential.GetNetworkCredential().Password 
                if($? -eq $False){
                    Write_OH("ログインに失敗しました")
                    exit_common 1
                }
            }else{
                Write_OH("手動ログインに失敗しました")
                exit_common 1
            }
        }
        az account set --subscription $env | ConvertFrom-Json
        if($? -eq $False){
            Write_OH("サブスクリプション環境の指定が誤っています")
            exit_common 1
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }

    # service princiopalでのログイン用
    azsplogin($env){
 # ログインIDとパスの処理
        if(Test-Path "./username"){
            $username = Get-Content "./username"
            $psw = (Get-Content "./psw"  | ConvertTo-SecureString)
            $Credential = New-Object System.Management.Automation.PSCredential $username,$psw
        }else{
            Write-Host("Azureのログイン情報を暗号化して保存します。")
            Write-Host("AzureのログインID(@gintra.bc-glex.net付き)とパスワードを入力してください")
            $Credential = Get-Credential
            $Credential.UserName > "./username"
            $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
            Write-Host("Azureのログイン情報を保存しました。このまま終了します。初回実行時は再度実行してください")
            Exit 0
        }
        az login --service-principal -u $Credential.UserName -p $Credential.GetNetworkCredential().Password --tenant $env| ConvertFrom-Json
        if($? -eq $False){
            Write_OH("ログインに失敗しました")
            exit_common 1
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }
}