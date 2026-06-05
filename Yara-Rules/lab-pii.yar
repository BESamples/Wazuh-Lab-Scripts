rule PII_SSN_Detected
{
    strings:
        $ssn = /[0-9]{3}-[0-9]{2}-[0-9]{4}/

    condition:
        $ssn
}

rule PII_Password_Detected
{
    strings:
        $p1 = "password"
        $p2 = "Password"
        $p3 = "PASSWORD"

    condition:
        any of them
}

rule PII_Payroll_Detected
{
    strings:
        $a = "Payroll"
        $b = "Employee Salary"
        $c = "Direct Deposit"

    condition:
        any of them
}
