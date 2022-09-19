# креды от домена, вписываем свою учётку вместо ***
$am_cred = Get-Credential -credential '***'

# адрес сервера с AD
$server = '***'

# открываем csv с данными из папки со скриптом
$csv = Import-Csv -Delimiter ';' -Path .\ad_create_user.csv

# нагребаем данные в виде почта:пароль в массив
$email = @( $csv | select -Property email, password )
$emailpass = @{}
foreach($i in $email){$emailpass.add($i.email, $i.password)}

# запускаем цикл с получением данных по имени почты из домена infotecs, сохраняем их в переменные
foreach($i in $emailpass.Keys) {
$inf_user = Get-ADUser -Filter "EmailAddress -eq '$i'" -Properties *
$password = ConvertTo-SecureString $emailpass[$i] -AsPlainText -Force
$city = $inf_user | Select -expand City
$company = $inf_user | Select -expand Company
$department = $inf_user | Select -expand Department
$givenname = $inf_user | Select -expand GivenName
$surname = $inf_user | Select -expand Surname
$name = -join($givenname, " ", $surname)
$samaccountname = (-join($surname, ".", $givenname)).ToLower()
if ($samaccountname.Length -gt 20) { $samaccountname = $samaccountname.Substring(0,20) }
$title = $inf_user | Select -expand Title
$userprincipalname = (-join($surname, ".", $givenname, "@am.int")).ToLower()
write-output $samaccountname $userprincipalname

# создаём юзеров с получеными данными в нашем домене
New-ADUser -AccountPassword $password -City $city -Company $company -Credential $am_cred -Department $department -DisplayName $name -EmailAddress $i -Enabled $true -GivenName $givenname -Name $name -samaccountname $samaccountname -Server $server -Surname $surname -Title $title -UserPrincipalName $userprincipalname -PasswordNeverExpires $true -Path "OU=amusers,DC=am,DC=int"
}