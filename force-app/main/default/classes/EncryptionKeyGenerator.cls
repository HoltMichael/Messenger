public with sharing class EncryptionKeyGenerator {
    public static void onInstall(InstallContext context) {
        Blob cryptoKey = Crypto.generateAesKey(256);
        String cryptoKeyAsString = EncodingUtil.base64encode(cryptoKey);


        try{
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
        }catch(Exception e)
        {
            system.debug(e.getMessage());
        }
    }
}
