public without sharing class SendMessageHandler {
    @AuraEnabled
    public static string sendMessage(String message, String thread, String recipientId, String senderId, String name){ 
        system.debug(name);
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
            publishEvent(recipientId, senderId, name, encryptedMsg);
        }
        return null;
    }

    public static void publishEvent(string recip, String sdr, String nm, String msg){
        String timeStamp = getTimeStamp();
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip, MHolt__Timestamp__c = timeStamp, MHolt__From_Name__c = nm);
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

    /*@AuraEnabled
    public static String getChatHistory(String user1, String user2, integer days){
        system.debug('user1: ' + user1);
        system.debug('user2: ' + user2);
        system.debug('days: ' + days);
        days = 7;
        user1 = '%' + user1 + '%';
        user2 = '%' + user2 + '%';
        List<String> conversations = new List<String>();
        List<MHolt__Chat_Message__c> chats = [SELECT name, MHolt__Conversation__c, MHolt__Participants__c 
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Participants__c like :user1
                                                AND MHolt__Participants__c like :user2
                                                AND createdDate = LAST_N_DAYS:7];
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        system.debug(chats);
        Blob decryptedData;
        for(MHolt__Chat_Message__c chat : chats){
            Blob base64EncryptedMessage = EncodingUtil.base64decode(chat.MHolt__Conversation__c);
            decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        }
        return decryptedData.toString();
    }*/

    @AuraEnabled
    public static String getChatHistory(String user1, String user2, integer days){
        user1 = '%' + user1 + '%';
        user2 = '%' + user2 + '%';
        List<MHolt__Chat_Message__c> chats = new List<MHolt__Chat_Message__c>();
        try{
            chats = [SELECT name, MHolt__Conversation__c, MHolt__Participants__c 
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Participants__c like :user1
                                                AND MHolt__Participants__c like :user2
                                                AND createdDate = LAST_N_DAYS:7];
        }catch(ListException e){

        }
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob base64EncryptedMessage = EncodingUtil.base64decode(chats[0].MHolt__Conversation__c);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        return decryptedData.toString();
        //return encodingUtil.base64encode(decryptedData);

    }

    @AuraEnabled
    public static String getTimeStamp(){
        DateTime dt = system.NOW();
        Integer day = dt.dayGmt();
        String mth = getMonthWritten(dt.monthGmt());
        Integer year = dt.yearGmt();
        Integer hour = dt.hourGmt();
        Integer min = dt.minuteGmt();
        Integer sec = dt.secondGmt();

        return day + ' ' + mth + ' ' + String.valueOf(year).mid(2,2) + ' ' + hour + ':' + min + ':' + sec; 
        }

    public static String getMonthWritten(integer mth){
        switch on mth {
            when 1 {
                return 'Jan';
            }when 2 {		
                return 'Feb';
            }when 3 {
                return 'Mar';
            }when 4 {		  
                return 'Apr';
            }when 5{
                return 'May';
            }when 6{
                return 'Jun';
            }when 7{
                return 'Jul';
            }when 8{
                return 'Aug';
            }when 9{
                return 'Sep';
            }when 10{
                return 'Oct';
            }when 11{
                return 'Nov';
            }when else{
                return 'Dec';
            }
        }
    }

    @AuraEnabled
    public static String decryptMessage(String msg, String snd){
        String nm = '';
        try{
            User sender = [SELECT Id, Name FROM User WHERE id =: snd][0];
            nm = sender.Name;
            system.debug(sender);
        }catch(ListException e){
            //No sender param
        }
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob base64EncryptedMessage = EncodingUtil.base64decode(msg);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        return nm + ':' + decryptedData.toString();
    }

}