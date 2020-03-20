public without sharing class SendMessageHandler {
    @AuraEnabled
    public static string sendMessage(String message, String thread, String recipientId, String senderId){ 
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, Blob.valueOf(message));
        String encryptedMsg = EncodingUtil.base64encode(encryptedData);
        
        MHolt__Chat_Message__c msg = null;
        try{
            String participant1 = '%' + recipientId + '%';
            String participant2 = '%' + senderId + '%';
            msg = [SELECT name, MHolt__Conversation__c, MHolt__Participants__c 
                                            FROM MHolt__Chat_Message__c 
                                            WHERE MHolt__Participants__c like :participant1
                                            AND MHolt__Participants__c like :participant2
                                            AND createdDate = TODAY][0];
        }catch(System.ListException e){
            msg = new MHolt__Chat_Message__c(Name = '', MHolt__Conversation__c = '', MHolt__Participants__c = senderId + ',' + recipientId, MHolt__Participant_1__c = recipientId, MHolt__Participant_2__c = senderId);
        }
        msg.MHolt__Conversation__c += encryptedMsg;
        Database.UpsertResult result = database.upsert(msg);
        if(result.isSuccess()){
            publishEvent(recipientId, senderId, encryptedMsg);
        }
        return null;
    }

    public static void publishEvent(string recip, String sdr, String msg){
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip);
        Database.SaveResult result = EventBus.publish(evt);
        /*// Inspect publishing result for each event
        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                System.debug('Successfully published event.');
            } else {
                for(Database.Error err : sr.getErrors()) {
                    System.debug('Error returned: ' +
                                err.getStatusCode() +
                                ' - ' +
                                err.getMessage());
                }
            }       
        }*/
    }

    @AuraEnabled
    public static String decryptMessage(String msg, String snd){
        User sender = [SELECT Id, Name FROM User WHERE id =: snd][0];
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob base64EncryptedMessage = EncodingUtil.base64decode(msg);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        return sender.name + ': ' + decryptedData.toString();
    }
}