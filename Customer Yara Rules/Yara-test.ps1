Set-Content -Path "C:\Program Files (x86)\ossec-agent\active-response\bin\yara\rules\test-malware.yar" -Value @'
rule Test_Malware_String
{
    strings:
        $a = "MALWARE_TEST_STRING"

    condition:
        $a
}
'@

& "C:\Program Files (x86)\ossec-agent\active-response\bin\yara\yara64.exe" -s "C:\Program Files (x86)\ossec-agent\active-response\bin\yara\rules\test-malware.yar" "C:\Wazuh-Test\evil.txt"
