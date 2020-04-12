public without sharing class SendMessageHandler {
    private static Map<String, Integer> monthIntegersByName = new Map<String, Integer>
    {'Jan' => 1, 'Feb' => 2,'Mar' => 3, 'Apr' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12};
    private static Map<Integer, String> monthNamesByInteger = new Map<Integer, String>
    {1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'Aug', 9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'};
    
    @AuraEnabled
    public static string sendMessage(String message, String thread, String recipientId, String senderId, String name){ 
        system.debug(name);
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, Blob.valueOf(message));
        String encryptedMsg = EncodingUtil.base64encode(encryptedData);
        List<User> users = getUsersWithSidkey(new List<String>{recipientId, senderId});
        MHolt__Chat_Message__c msg = new MHolt__Chat_Message__c(Name = '', MHolt__Message__c = encryptedMsg, MHolt__Participant_1__c = recipientId, MHolt__Participant_2__c = senderId);

        Database.UpsertResult result = database.upsert(msg);
        if(result.isSuccess()){
            publishEvent(recipientId, senderId, name, encryptedMsg);
        }
        return null;
    }

    public static void publishEvent(string recip, String sdr, String nm, String msg){
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip, MHolt__From_Name__c = nm);
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


    /*
        shareContent
        User has attempted to send a file to their recipient. Loop through all of the files which have been sent
        And create a ContentDocumentLink to the user or group to be shared with.
    */
    @AuraEnabled
    public static String shareContent(id userOrGroupId, List<id> documentIds){
        List<ContentDocumentLink> cdlsToInsert = new List<ContentDocumentLink>();
        String result;
        for(id contentdocId : documentIds){
            ContentDocumentLink cdl = new ContentDocumentLink(LinkedEntityId = userOrGroupId, ShareType = 'V', ContentDocumentId=contentdocId);
            cdlsToInsert.add(cdl);
        }
        system.debug(cdlsToInsert);
        try{
            insert cdlsToInsert;
            result = 'Success';
        }catch(exception e){
            result = e.getMessage();
        }
        return result;
    }

    /*
        getUsersWithSidkey
        Takes a list of user IDs, returns a list of users with TimeZoneSidKey field
        Query required for getTimeInTimezoneForUsers method. Abstracted away, so getTimeInTimezoneForUsers 
        can be called within a loop without hitting SOQL limits.
    */
    public static List<User> getUsersWithSidkey(List<Id> userIds){
        return [SELECT Id, TimeZoneSidKey FROM User WHERE Id IN: userIds];
    }

    /*
        getTimeInTimezoneForUsers
        A TimeZoneSidKey has a value of eg. (GMT+11:00) Solomon Islands Time (Pacific/Guadalcanal)
        And a label of Pacific/Guadalcanal. 
        Method extracts the specific time values and then adds/deducts from GMT to provide a time to the recipient in their region.
    */
    public static Map<Id, DateTime> getTimeInTimezoneForUsers(List<User> users, DateTime GMTTime){
        system.debug('GMTTime: ' + GMTTime);
        Map<Id, DateTime> userTimes = new Map<Id, DateTime>();
        Schema.DescribeFieldResult fieldResult = User.TimeZoneSidKey.getdescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        for(User u : users){
            for(Schema.PicklistEntry p : ple)
            {
                if(p.getValue() == u.TimeZoneSidKey){
                    //Initiate the user time as GMT
                    DateTime userTime = GMTTime;
                    String offset = p.getLabel().substringBetween('T',')');
                    //give us the hour / minute offsets
                    List<String> denominationOffsets = offset.split(':');
                    system.debug('offset: ' + offset);
                    system.debug('denominationOffsets: ' + denominationOffsets);
                    userTime = userTime.addHours(Integer.valueOf(denominationOffsets[0]));
                    userTime = userTime.addMinutes(Integer.valueOf(denominationOffsets[1]));
                    userTimes.put(u.id, userTime);
                }
            }
        }
        
        return userTimes;
    }

    @AuraEnabled
    public static List<MessageWrapper> getChatHistory(String user1, String user2, Integer lim){
        system.debug(lim);
        List<MessageWrapper> returnMessages = new List<MessageWrapper>();
        MHolt__Chat_Message_Code__mdt cryptoKeyAsString = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
        Blob cryptoKey = EncodingUtil.base64decode(cryptoKeyAsString.MHolt__Key__c);
        String user1Like = '%' + user1 + '%';
        String user2Like = '%' + user2 + '%';
        
        //Need to order DESC to get the latest messages, as we pull a maximum of 
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT name, OwnerId, Owner.Name, MHolt__From_Name__c, MHolt__Message__c, MHolt__Participants__c, createdDate
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Participants__c like :user1Like
                                                AND MHolt__Participants__c like :user2Like
                                                ORDER BY createdDate DESC
                                                Limit :lim];
        system.debug(chatMsgs);
        List<User> users = getUsersWithSidkey(new List<String>{user1, user2});
        //Loop over the list of messages backwards, as they had to be pulled out of the DB DESC
        for(Integer i = chatMsgs.size() - 1; i >= 0; i--){
            MHolt__Chat_Message__c msg = chatMsgs[i];
            String DbMsg = msg.MHolt__Message__c;
            Blob Dbbase64EncryptedMessage = EncodingUtil.base64decode(DbMsg);
            blob DbdecryptedString = Crypto.decryptWithManagedIV('AES256', cryptoKey, DBbase64EncryptedMessage);
            
            Map<Id, DateTime> timesByUser = getTimeInTimezoneForUsers(users, msg.createdDate);
            MessageWrapper wrap = new MessageWrapper(DbdecryptedString.toString(), msg.OwnerId, msg.Owner.Name, getTimeStamps(new List<DateTime>{timesByUser.get(userinfo.getuserid())})[0]);

            returnMessages.add(wrap);
        }
        system.debug('returnMessages: ' + returnMessages);
        return returnMessages;
        
    }

    /*
        getTimeStamps
        Takes a list of date times and returns a list of formatted strings
        To remove confusion between date formats, the String uses the following: "5 Apr 20 10:30:00"
    */
    @AuraEnabled
    public static List<String> getTimeStamps(List<DateTime> dts){
        List<String> timestamps = new List<String>();
        for(DateTime dt : dts){
            Integer day = dt.dayGmt();
            String mth =  monthNamesByInteger.get(dt.monthGmt());
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

    @AuraEnabled
    public static MessageWrapper decryptMessage(String msg, String snd){
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

        List<User> currentUser = getUsersWithSidkey(new List<String>{userInfo.getUserId()});
        Map<Id, DateTime> timesByUser = getTimeInTimezoneForUsers(currentUser, system.now());
        MessageWrapper wrap = new MessageWrapper(decryptedData.toString(), null, null, getTimeStamps(new List<DateTime>{timesByUser.get(userInfo.getUserId())})[0]);

        return wrap;
    }

    public class MessageWrapper{
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String senderId;
        @AuraEnabled
        public String senderName;
        @AuraEnabled
        public String timestamp;
        @AuraEnabled
        public string cls;

        public MessageWrapper(String m, String i, String n, String t){
            message = m;
            timestamp = t;
            senderId = i;
            senderName = n;
        }
 
        public MessageWrapper(String m, String i, String n){
            message = m;
            senderId = i;
            senderName = n;
        }

    }
}