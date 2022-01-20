# �p�r�FAzureCli�𗘗p����ps1�X�N���v�g����̌��ƂȂ郂�W���[���ł��B
# ����P�̂ł����O�C���Ɏg�p�ł��܂�
# ���s�p�̃X�N���v�g��execute.ps1�Ȃ̂Ŏ��ۂ̎g�p���@�͂������������������


# ��{�����Ɋւ���N���X�͂����ɋL��
# �ȉ��̂悤�Ɍp�����ăN���X��ҏW���Ďg�p��������


# using module ./azcli_mod.psm1

# class ClassName : azmod{
    # test(){
    #     if(error){
    #         exit_common 1
    #     }
    # }
# }


# �g�p��
# . ./extendClass.ps1

# $classInstance = New-Object extendClass
# $rg = "Dev-RG-TEST-001"
# $resources = "tesfr901v"
# $type = "Microsoft.Compute/virtualMachines"
# $classInstance.set_resource($rg,$resources,$type)

# $env = "����"
# $classInstance.azlogin($env)



$Error.Clear()
$global:DefaultErrorActionPreference=[String]$ErrorActionPreference
$ErrorActionPreference="Continue"

# �o�͂Ɋւ���֐�
function Write_OH($arg1){
    $line = "$(Get-Date -Format "[yyyy/MM/dd HH:mm:ss]") $arg1"
    Write-Host($line)
    Write-Output($line)
    return
}

# �I������
function exit_common($arg1){
    #����I����
    if ($arg1 -eq 0 ) {
        Write_OH("�v���O�����͐���I�����܂���") 
    #�ُ�I����
    }else{
        Write_OH("�v���O�����͏����𒆒f���܂���") 
    }
    $ErrorActionPreference=$DefaultErrorActionPreference
    exit $arg1
}


class azmod{
    $global:input_data = @{}

    # �ϐ��i�[�p
    set_resources([String]$rg,[String]$resources,[String]$keyname,[String]$type){
        $rlist = (az resource list --resource-group $rg | ConvertFrom-Json)
        if($? -eq $False){
            Write_OH("���\�[�X�O���[�v�̎w�肪����Ă��܂�") 
            exit_common 1
        }
        if($rlist.Length -eq 0){
            Write_OH("���\�[�X�O���[�v�̎w�肪����Ă��܂�") 
            exit_common 1
        }
        if(($rlist.type | sort | Get-Unique | Where-Object{$_ -eq $type}).Count -eq 0){
            Write_OH("type�̎w�肪�ԈႦ�Ă��܂�")
            Write_OH("���̓f�[�^: $type")
            Write_OH("���L�ꗗ���Q�l�Ɏw�肵�Ȃ����Ă������� \n $rlist")
            exit_common 1
        }
        $exit_code = 0
        Write_OH("ResourceGroupName: $rg") 
        foreach($target in $resources.split(',')){
            $target_info = $rlist|Where-Object{$_.name -eq $target}
            Write_OH("Resource Name: $target")  
            if($target_info.name -ne $target){
                Write_OH("���݂��Ȃ����\�[�X�����w�肳��Ă��܂�")�@
                Write_OH("Value: $($target.name)") 
                $exit_code += 1
            }
            Write_OH("ResourceGroupName: $($target_info.type)") 
            if($target_info.type -ne $type){
                Write_OH("$($target_info.type) �ȊO�̃^�C�v�����w�肳��Ă��܂�")
                Write_OH("Value: $type")
                $exit_code += 1
            }
        }
        # ��肪����ꍇ�͏����I��
        if($exit_code -gt 0){
            exit_common $exit_code
        }
        # ��肪�Ȃ���΂��̂܂ܕϐ��ɒl���i�[
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add( "rg", $rg )
        }
        $this.input_data.Add( $keyname, $resources.split(',') )
    }

    set_resource([String]$rg,[String]$resource,[String]$keyname,[String]$type){
        $rlist = (az resource list --resource-group $rg | ConvertFrom-Json)
        if(($? -eq $False) -or ($rlist.Length -eq 0)){
            Write_OH("���\�[�X�O���[�v�̎w�肪����Ă��܂�") 
            $exit_code += 1
            exit_common 1
        }
        if(($rlist.type | sort | Get-Unique | Where-Object{$_ -eq $type}).Count -eq 0){
            Write_OH("type�̕\�L���ԈႦ�Ă��܂�")
            Write_OH("���̓f�[�^: $type")
            Write_OH("���L�ꗗ���Q�l�Ɏw�肵�Ȃ����Ă�������")
            Write_OH($rlist.type | sort | Get-Unique)
            exit_common 1
        }
        Write_OH("ResourceGroupName: $rg") 
        $target_info = $rlist|Where-Object{$_.name -eq $resource}
        Write_OH("Resource Name: $resource")  
        if($target_info.name -ne $resource){
            Write_OH("���݂��Ȃ����\�[�X�����w�肳��Ă��܂�")�@
            Write_OH("Value: $($target_info)") 
            exit_common 1
        }
        Write_OH("Resourcetype: $($target_info.type)") 
        if($target_info.type -ne $type){
            Write_OH("$($target_info.type) �ȊO�̃��\�[�X���w�肳��Ă��܂�")
            Write_OH("Value: $type")
            exit_common 1
        }
        # ��肪�Ȃ���΂��̂܂ܕϐ��ɒl���i�[
        if($this.input_data.rg.Length -eq 0){
            $this.input_data.Add( "rg", $rg )
        }
        $this.input_data.Add( $keyname, $resource )
    }

    # �ϐ��i�[�p
    set_appgw([String]$appgw,[String]$rg){
        $keyname = "appgw"
        $type = "Microsoft.Network/applicationGateways"
        if($this.input_data.appgw.Length -eq 0){
            $this.set_resource($rg,$appgw,$keyname,$type)
        }elseif($this.input_data.appgw -ne $appgw){
            Write_OH("�ϐ�AppGW�� $($this.input_data.appgw)�@���� $appgw �֍X�V���܂�")
            $this.input_data.appgw = $appgw
        }else{
            Write_OH("�ϐ�AppGW�͐ݒ�ς݂ł�")
        }
    }
    set_lb([String]$lb,[String]$rg){
        $keyname = "lb"
        $type = "Microsoft.Network/loadBalancers"
        if($this.input_data.lb.Length -eq 0){
            $this.set_resource($rg,$lb,$keyname,$type)
        }elseif($this.input_data.lb -ne $lb){
            Write_OH("�ϐ�lb�� $($this.input_data.lb)�@���� $lb �֍X�V���܂�")
            $this.input_data.lb = $lb
        }else{
            Write_OH("�ϐ�lb�͐ݒ�ς݂ł�")
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
            Write_OH("ResourceGroup����$($this.input_data.rg)����$($rg)�֍X�V���܂�")
            $this.input_data.rg = $rg
        }
    }
    set_output([String]$output){
        $this.input_data.Add( "output", $output )
        New-Item -Force -ItemType Directory $output
    }

    # ���O�C���p
    azlogin($env){
        try{
            $login_tester = az account list | convertfrom-json
        }catch{
            $login_tester = ""
        }
        if($login_tester.Count -eq 0){
            Write_OH("��v�f�F�؂��L���̃A�J�E���g�ł�CUI�ł̃��O�C�����ł��܂���")
            Write_OH("CUI���O�C������]����ꍇ�͊Y��RG�̌����̕t�^���ꂽServicePrincipal�������p��������")
            Write_OH("Web�u���E�U����蓮���O�C�������{��������")
            az login
        }
        az account set --subscription $env
        if($? -eq $False){
            az login
            az account set --subscription $env
            if($? -eq $False){
                Write_OH("�T�u�X�N���v�V�������̎w�肪����Ă��܂�")
                exit_common 1
            }
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }
    azautologin($env){
        # ���O�C��ID�ƃp�X�̏���
        if(Test-Path "./username"){
            $username = Get-Content "./username"
            $psw = (Get-Content "./psw"  | ConvertTo-SecureString)
            $Credential = New-Object System.Management.Automation.PSCredential $username,$psw
        }else{
            Write-Host("Azure�̃��O�C�������Í������ĕۑ����܂��B")
            Write-Host("Azure�̃��O�C��ID(@gintra.bc-glex.net�t��)�ƃp�X���[�h����͂��Ă�������")
            $Credential = Get-Credential
            $Credential.UserName > "./username"
            $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
            Write-Host("Azure�̃��O�C������ۑ����܂����B���̂܂܏I�����܂��B")
            Exit 0
        }
        az login -u $Credential.UserName -p $Credential.GetNetworkCredential().Password
        if($? -eq $False){
            Write_OH("���O�C���Ɏ��s���܂���(��v�f�F�؂��L���̃A�J�E���g�ł̓��O�C���ɕK�����s���܂�)")
            $flag = Read-host("�p�X���[�h��ύX���܂������H(y/n)")
            if($flag[0] -eq "y"){
                $Credential = Get-Credential -u $Credential.UserName -m "�p�X���[�h�Đݒ�"
                $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
                az login -u $Credential.UserName -p $Credential.GetNetworkCredential().Password 
                if($? -eq $False){
                    Write_OH("���O�C���Ɏ��s���܂���")
                    exit_common 1
                }
            }else{
                Write_OH("�蓮���O�C���Ɏ��s���܂���")
                exit_common 1
            }
        }
        az account set --subscription $env | ConvertFrom-Json
        if($? -eq $False){
            Write_OH("�T�u�X�N���v�V�������̎w�肪����Ă��܂�")
            exit_common 1
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }

    # service princiopal�ł̃��O�C���p
    azsplogin($env){
 # ���O�C��ID�ƃp�X�̏���
        if(Test-Path "./username"){
            $username = Get-Content "./username"
            $psw = (Get-Content "./psw"  | ConvertTo-SecureString)
            $Credential = New-Object System.Management.Automation.PSCredential $username,$psw
        }else{
            Write-Host("Azure�̃��O�C�������Í������ĕۑ����܂��B")
            Write-Host("Azure�̃��O�C��ID(@gintra.bc-glex.net�t��)�ƃp�X���[�h����͂��Ă�������")
            $Credential = Get-Credential
            $Credential.UserName > "./username"
            $Credential.Password | ConvertFrom-SecureString  | Set-Content "./psw"
            Write-Host("Azure�̃��O�C������ۑ����܂����B���̂܂܏I�����܂��B������s���͍ēx���s���Ă�������")
            Exit 0
        }
        az login --service-principal -u $Credential.UserName -p $Credential.GetNetworkCredential().Password --tenant $env| ConvertFrom-Json
        if($? -eq $False){
            Write_OH("���O�C���Ɏ��s���܂���")
            exit_common 1
        }
        $this.input_data.Add( "env", $env )
        $this.input_data.Add( "output", "output" )
        New-Item -Force -ItemType Directory "output"
    }
}
