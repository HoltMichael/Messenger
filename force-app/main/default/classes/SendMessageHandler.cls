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
        Map<Id, DateTime> times = getTimeInTimezoneForUsers(new List<String>{recipientId, senderId});

        MHolt__Chat_Message__c msg = new MHolt__Chat_Message__c(Name = '', MHolt__Timestamp1__c=times.get(senderId), MHolt__Timestamp2__c=times.get(recipientId), MHolt__Message__c = encryptedMsg, MHolt__Participant_1__c = recipientId, MHolt__Participant_2__c = senderId);

        Database.UpsertResult result = database.upsert(msg);
        if(result.isSuccess()){
            publishEvent(recipientId, senderId, name, encryptedMsg, times.get(senderId));
        }

        return null;
    }

    /*
        getTimeInTimezoneForUsers
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
    public static List<MessageWrapper> getChatHistory(String user1, String user2, integer days){
        List<MessageWrapper> returnMessages = new List<MessageWrapper>();
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

        for(MHolt__Chat_Message__c msg : chatMsgs){
            String DbMsg = msg.MHolt__Message__c;
            Blob Dbbase64EncryptedMessage = EncodingUtil.base64decode(DbMsg);
            blob DbdecryptedString = Crypto.decryptWithManagedIV('AES256', cryptoKey, DBbase64EncryptedMessage);
            
            MessageWrapper wrap = new MessageWrapper(DbdecryptedString.toString(), msg.OwnerId, msg.Owner.Name);

            if(msg.OwnerId == userinfo.getuserid()){
                wrap.timestamp = msg.MHolt__Timestamp1_String__c;
                
                //returnMessages.add(msg.MHolt__Timestamp1_String__c + ' ' + msg.Owner.Name + ':' + DbdecryptedString.toString());
            }else{
                wrap.timestamp = msg.MHolt__Timestamp2_String__c;
                //returnMessages.add(msg.MHolt__Timestamp2_String__c + ' ' + msg.Owner.Name + ':' + DbdecryptedString.toString());
            }
            returnMessages.add(wrap);
        }
        system.debug('returnMessages: ' + returnMessages);
        return returnMessages;
        
    }

    public static void publishEvent(string recip, String sdr, String nm, String msg, DateTime times){
        String timesAsString = getTimeStamps(new List<DateTime>{times})[0];
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip, MHolt__Timestamp__c = timesAsString, MHolt__From_Name__c = nm);
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
        getTimeStampForRecipient
        Rather than use the current timezone of the user, use the exact time the sender sent the message to
        calculate the time of the recipient. This way, the times will match up exactly, even across timezones
    */
    @AuraEnabled
    public static string getTimeStampForRecipient(String tm){
        List<String> dateValues = tm.split(' ');
        List<String> timeValues = dateValues[3].split(':');
        Datetime recipientTime = Datetime.newInstance(Integer.valueOf(dateValues[2]), monthIntegersByName.get(dateValues[1]), Integer.valueOf(dateValues[0]), Integer.valueOf(timeValues[0]), Integer.valueOf(timeValues[1]), Integer.valueOf(timeValues[2]));
        String recipientTimeString = getTimeStamps(new List<DateTime>{recipientTime})[0];
        return recipientTimeString;
    }

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

    public class MessageWrapper{
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String timestamp;
        @AuraEnabled
        public String senderId;
        @AuraEnabled
        public String senderName;

        public MessageWrapper(String m, String t, String i, String n){
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