@isTest
public with sharing class EncryptionKeyGenerator_Test {
    @isTest
    public static void onInstallTest() {
        Test.startTest();
            EncryptionKeyGenerator.onInstall(null);
        Test.stopTest();
    }
}
