rule Ransomware_Note_Detected
{
    strings:
        $a = "Your files have been encrypted"
        $b = "pay the ransom"
        $c = "bitcoin wallet"
        $d = "decrypt your files"

    condition:
        any of them
}
