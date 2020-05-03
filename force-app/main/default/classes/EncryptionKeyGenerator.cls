/*
    EncryptionKeyGenerator
    Author: Michael Holt
    Date: 25th April 2020

    On install into a Salesforce instance, generated a crypto key specific to this particular org
    That is used for the process of all encrypting and decrypting of messages when sent using the Messenger app.
*/

public without sharing class EncryptionKeyGenerator implements InstallHandler{
    public static void onInstall(InstallContext context) {
        Blob cryptoKey = Crypto.generateAesKey(256);
        String cryptoKeyAsString = EncodingUtil.base64encode(cryptoKey);

        try{
            //Do not generate a second key on upgrade.
            List<MHolt__Chat_Message_Code__mdt> cryptoKeyMetadata = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'];
            if(cryptoKeyMetadata.size() == 0){
                Metadata.CustomMetadata customMetadata =  new Metadata.CustomMetadata();
                customMetadata.fullName = 'MHolt__Chat_Message_Code__mdt.'+'key';
                customMetadata.label = 'Key';

                Metadata.CustomMetadataValue nameField = new Metadata.CustomMetadataValue();
                nameField.field = 'MHolt__Key__c';
                nameField.value = cryptoKeyAsString;
                customMetadata.values.add(nameField);

                Metadata.DeployContainer mdContainer = new Metadata.DeployContainer();
                mdContainer.addMetadata(customMetadata);
                MHolt.CustomMetadataCallback callback = new MHolt.CustomMetadataCallback();
                Id jobId = Metadata.Operations.enqueueDeployment(mdContainer, callback);
            }
        }catch(Exception e)
        {
            system.debug(e.getMessage());
        }
    }
}
