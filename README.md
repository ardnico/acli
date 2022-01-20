# Azexecute

「parameter.csv」(Shift-jis)を読み込んでAzureの操作を行います。
実行結果は同階層のoutputフォルダに出力します。
操作するリソースの情報はjson形式で出力します。


## How to use

- 使用前提条件
1. Az cliインストール済み(Local PC)
2. 対象のリソースへのアクセス権限(RBAC)

- 使用方法

1. csvファイルを作成してください。
各パラメータの指定の仕方は以下の通りです。

CSVカラム名：Action,Target,ResourceGroupName,Env,Param1,Param2,Param3,Param4,Param5,Param6,Param7
Action列：操作するアクションを指定します
Target:操作対象のリソース名を指定します
ResourceGroupName:リソースグループ名を指定します
Env:サブスクリプション環境名を指定します
Param1~7: アクションに応じて入力します。一つのParamに対して複数の値を引き渡したいときは以下のように指定します
 …Env,"a,b,c",Param2,…

### chAppGWsize
アプリケーションゲートウェイのサイズ変更を行います。
Targetには対象のアプリケーションゲートウェイ名を指定し、
Param1にインスタンス数、Param2にキャパシティサイズを指定します。
キャパシティサイズは以下から指定ください
Standard_Large / Standard_Medium / Standard_Small / Standard_v2 / WAF_Large / WAF_Medium / WAF_v2
※通常はStandard_Medium
※Action～Param2までは必須です


### isolatefromAppGW / mergeintoAppGW
アプリケーションゲートウェイからの切り離し、接続を行います。
切り離し時は「isolatefromAppGW」を指定し、接続時は「mergeintoAppGW」を指定ください。
Targetに切り離し元のアプリケーションゲートウェイ名を指定し、Param1に切り離しを実施したいVM名を指定ください。

### deleteSettingsFromAppGW
リスナー、ルール、プローブ、アドレスプール、HTTP設定、SSL証明から、
Param1に指定した文字列を含む設定を削除します。
※ここにはFQDN名がよく指定されています

### GetPerfVMS
VMのメトリック情報(CPU使用率)を取得します。
Param1には開始日時、Param2には終了日時を指定してください。

### GetPerfVMSCurrent
直近5分のVMのメトリック情報(CPU使用率)を取得します。

### GetPerfAppgw
アプリケーションゲートウェイのメトリック情報(総要求数、リクエスト失敗数、平均CPU使用率)を取得します。
Param1には開始日時、Param2には終了日時を指定してください。

### GetPerfAppgwCurrent
直近5分のアプリケーションゲートウェイのメトリック情報(総要求数、リクエスト失敗数、平均CPU使用率)を取得します。

### GetPerfVMsize
対象リソースグループ内のVMのサイズ一覧を取得します。

### GetPerfVMactivity
対象VMの90日間の起動/停止アクティビティログを取得します。


### 入力例

|Action|Target|ResourceGroupName|Env|Param1|Param2|Param3|Param4|Param5|Param6|Param7|
|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|:--|
|chAppGWsize|TestAppGW-01|ResourceGroup-001|EnvironmentName|20|Standard_Medium||||||
|isolatefromAppGW|TestAppGW-01|ResourceGroup-001|EnvironmentName|"TestVM-01,testVM-03v"|||||||
|mergeintoAppGW|TestAppGW-01|ResourceGroup-001|EnvironmentName|testdb901v|||||||
|deleteSettingsFromAppGW|TestAppGW-01|ResourceGroup-001|EnvironmentName|testfqdn.ne.jp|||||||
|GetPerfVMS|TestVM-01|ResourceGroup-001|EnvironmentName|"2021/10/21 00:00:00"|"2021/10/22 00:15:00"||||||
|GetPerfVMSCurrent|TestVM-01|ResourceGroup-001|EnvironmentName||||||||
|GetPerfAppgw|TestAppGW-01|ResourceGroup-001|EnvironmentName|"2021/10/21 00:00:00"|"2021/10/22 00:15:00"||||||
|GetPerfAppgwCurrent|TestAppGW-02|ResourceGroup-001|EnvironmentName||||||||
|GetPerfVMsize||ResourceGroup-001|EnvironmentName||||||||
|GetPerfVMactivity|TestVM-01|ResourceGroup-001|EnvironmentName||||||||
||||||||||||
||||||||||||



CSV内に指定した操作は一括で行うため、切り離しと接続操作を分ける場合は別個に「parameter.csv」を作成して、
使用する際に「Execute_az.bat」と同じ階層へ配置してください。
※ファイル名は必ず「parameter.csv」と指定すること。

