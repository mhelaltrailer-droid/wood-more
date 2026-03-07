# تشغيل firebase login باستخدام المسار الكامل لـ npx
# انسخ هذا الملف أو نفّذ محتواه في PowerShell

$nodePath = "$env:ProgramFiles\nodejs"
$npmPath  = "$env:AppData\npm"
$env:Path = "$nodePath;$npmPath;$env:Path"

& "$nodePath\npx.cmd" firebase login
