public without sharing class SendMessageHandler {
    @AuraEnabled
    public static string sendMessage(String message, String thread, String recipientId, String senderId, String name){ 
        system.debug(name);
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, Blob.valueOf(message));
        String encryptedMsg = EncodingUtil.base64encode(encryptedData);
        Map<Id, DateTime> times = getTimeInTimezoneForUsers(new List<String>{recipientId, senderId});

        MHolt__Chat_Message__c msg = new MHolt__Chat_Message__c(Name = '', MHolt__Timestamp1__c=times.get(senderId), MHolt__Timestamp2__c=times.get(recipientId), MHolt__Message__c = encryptedMsg, MHolt__Participant_1__c = recipientId, MHolt__Participant_2__c = senderId);

        Database.UpsertResult result = database.upsert(msg);
        if(result.isSuccess()){
            publishEvent(recipientId, senderId, name, encryptedMsg, times);
        }

        return null;
    }

    /*
        A TimeZoneSidKey has a value of eg. (GMT+11:00) Solomon Islands Time (Pacific/Guadalcanal)
        And a label of Pacific/Guadalcanal. 
        Need to extract the specific time values and then detuct from the GMT to provide a time to the recipient in their region.
    */
    public static Map<Id, DateTime> getTimeInTimezoneForUsers(List<id> userIds){
        List<User> users = [SELECT Id, TimeZoneSidKey FROM User WHERE Id IN: userIds];
        Map<Id, DateTime> userTimes = new Map<Id, DateTime>();
        Schema.DescribeFieldResult fieldResult = User.TimeZoneSidKey.getdescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for(User u : users){
            for(Schema.PicklistEntry p : ple)
            {
                if(p.getValue() == u.TimeZoneSidKey){
                    //Initiate the user time as GMT
                    DateTime userTime = System.now();
                    String offset = p.getLabel().substringBetween('T',')');
                    //give us the hour / minute offsets
                    List<String> denominationOffsets = offset.split(':');
                    userTime = userTime.addHours(Integer.valueOf(denominationOffsets[0]));
                    userTime = userTime.addMinutes(Integer.valueOf(denominationOffsets[1]));
                    userTimes.put(u.id, userTime);
                }
            }
        }
        
        return userTimes;
    }

    @AuraEnabled
    public static List<string> getChatHistory(String user1, String user2, integer days){
        List<String> returnMessages = new List<String>();
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        user1 = '%' + user1 + '%';
        user2 = '%' + user2 + '%';
        
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT name, OwnerId, Owner.Name, MHolt__From_Name__c, MHolt__Message__c, MHolt__Participants__c, createdDate,
                                                        MHolt__Timestamp1_String__c, MHolt__Timestamp2_String__c
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Participants__c like :user1
                                                AND MHolt__Participants__c like :user2
                                                AND createdDate = LAST_N_DAYS:7
                                                ORDER BY createdDate Asc];

        system.debug('chatMsgs: ' + chatMsgs);  
        for(MHolt__Chat_Message__c msg : chatMsgs){
            system.debug('Id: ' + chatMsgs);
            String DbMsg = msg.MHolt__Message__c;
            Blob Dbbase64EncryptedMessage = EncodingUtil.base64decode(DbMsg);
            blob DbdecryptedString = Crypto.decryptWithManagedIV('AES256', cryptoKey, DBbase64EncryptedMessage);
            if(msg.OwnerId == userinfo.getuserid()){
                returnMessages.add(msg.MHolt__Timestamp1_String__c + ' ' + msg.Owner.Name + ':' + DbdecryptedString.toString());
            }else{
                returnMessages.add(msg.MHolt__Timestamp2_String__c + ' ' + msg.Owner.Name + ':' + DbdecryptedString.toString());
            }
        }
        system.debug('returnMessages: ' + returnMessages);
        return returnMessages;
        
    }

    public static void publishEvent(string recip, String sdr, String nm, String msg, Map<Id, DateTime> times){
        //String timeStamp = getTimeStamp(system.NOW());
        List<String> timesAsString = getTimeStamps(times.values());
        system.debug('timesAsString: ' + timesAsString);
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip, MHolt__Timestamp__c = timesAsString[0], MHolt__Timestamp2__c = timesAsString[1], MHolt__From_Name__c = nm);
        system.debug(evt);
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
    public static List<String> getTimeStamps(List<DateTime> dts){
        List<String> timestamps = new List<String>();
        for(DateTime dt : dts){
            Integer day = dt.dayGmt();
            String mth = getMonthWritten(dt.monthGmt());
            Integer year = dt.yearGmt();
            Integer hour = dt.hourGmt();
            Integer min = dt.minuteGmt();
            Integer sec = dt.secondGmt();

            String hr = String.valueOf(hour);
            String mn = String.valueOf(min);
            String sc = String.valueOf(sec);

            if(hr.length() == 1){
                hr = '0' + hr;
            }
            if(mn.length() == 1){
                mn = '0' + mn;
            }
            if(sc.length() == 1){
                sc = '0' + sc;
            }

            timestamps.add(day + ' ' + mth + ' ' + String.valueOf(year).mid(2,2) + ' ' + hr + ':' + mn + ':' + sc);
        }
        return timestamps; 
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
        system.debug(msg);
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
        system.debug(nm + ':' + decryptedData.toString());
        return nm + ':' + decryptedData.toString();
    }
}