
####### çÏê¨íÜ

$alphabetstr = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!""#$%&\'()*+,-./:;<=>?@[\\]^`{|}~ "

function baseTenToN($x, $y)
{
    if($y -gt 10){return 0}
    [string]$basestr = ""
    while($x -gt 0){
        Write-host($basestr)
        [int]$testnum = [Math]::Truncate(($x / $y))
        if($testnum -ge 0){
            $leftnum = [int]($x % $y)
            write-host($leftnum)
            $basestr = "$([string]$leftnum)$basestr"
            $x = $testnum
        }
    }
    return $basestr
}

function baseNToTen([string]$x, [int]$y)
{
    if($y -gt 10){return 0}
    [string]$basestr = ""
    [int]$basenum = 0
    for($i=0;$i-lt$x.Length;i++){
        $x[($x.Length-1-$i)]*([Math]::Pow($y,$i))
    }
    return $basenum
}
baseNToTen 303 5

function Basento10(X,n):
    out = 0
    for i in range(1,len(str(X))+1):
        out += int(X[-i])*(n**(i-1))
    return out#int out

 decrypt(keyword):
    keyword = keyword.replace(".","0").replace("b","1").replace("3","2")
    decline = ""
    for i in range(int(len(keyword)/5)):
        tmpnum =f"{keyword[i*5]}{keyword[i*5+1]}{keyword[i*5+2]}{keyword[i*5+3]}{keyword[i*5+4]}"
        tmpnum = Basento10(tmpnum,3) -13
        decline += string.printable[tmpnum]
    return decline
        
def encode(keyword):
    encline = ""
    for i in range(len(keyword)):
        encline += str(Base10ton((string.printable.find(keyword[i])+13), 3)).zfill(5)
    encline = encline.replace("0",".").replace("2","3").replace("1","b")
    return encline
