/*
    SendMessageHandler - Utilities Class for the SendMessage LWC
    Author: Michael Holt
    Date: 25th April 2020

    Handles the sending and receiving of messages in the ChatWindow Component. 
    Includes pulling historic messages out of the database, encrypting and decrypting data, ensuring messages 
    are shown in the user's timezone and posting messages to Chatter, when requested.
*/

public without sharing class SendMessageHandler {
    //monthIntegersByName Map for the easy translation of month numbers to month names
    private static Map<String, Integer> monthIntegersByName = new Map<String, Integer>
    {'Jan' => 1, 'Feb' => 2,'Mar' => 3, 'Apr' => 4, 'May' => 5, 'June' => 6, 'July' => 7, 'Aug' => 8, 'Sep' => 9, 'Oct' => 10, 'Nov' => 11, 'Dec' => 12};
    //monthIntegersByName Map for the easy translation of month names to month numbers
    private static Map<Integer, String> monthNamesByInteger = new Map<Integer, String>
    {1 => 'Jan', 2 => 'Feb', 3 => 'Mar', 4 => 'Apr', 5 => 'May', 6 => 'June', 7 => 'July', 8 => 'Aug', 9 => 'Sep', 10 => 'Oct', 11 => 'Nov', 12 => 'Dec'};

    /*
        sendMessage
        Handles the encryption of the message to being sent.
        Stores the message to be sent in the MHolt__Chat_Message__c custom object. This enables messages to be pulled back in when the component is loaded on screen
        Calls method to send the platform event. This enables messages to be displayed on screen live, during this session.
    */
    @AuraEnabled
    public static string sendMessage(String message, String recipientId, String senderId, String name){ 
        Blob cryptoKey = getCryptoKey();
        Blob encryptedData = Crypto.encryptWithManagedIV('AES256', cryptoKey, Blob.valueOf(message));
        String encryptedMsg = EncodingUtil.base64encode(encryptedData);
        List<User> users = getUsersWithSidkey(new List<String>{recipientId, senderId});
        MHolt__Chat_Message__c msg = new MHolt__Chat_Message__c(Name = '', MHolt__Message__c = encryptedMsg, MHolt__Participant_1__c = recipientId, MHolt__Participant_2__c = senderId);

        try{
            database.insert(msg);
            //Future: return the publish errors, combined with the database errors
            String errors = publishEvent(recipientId, senderId, name, encryptedMsg, msg.id);
        }catch(exception e){
            return e.getMessage();
        }
        return 'Success';
    }

    /*
        publishEvent
        Publishes the platform event with the message being sent on it, so that any current subscribers see the message appear on screen.
        Including the sender of the message
    */
    public static String publishEvent(string recip, String sdr, String nm, String msg, String id){
        MHolt__Message__e evt = new MHolt__Message__e(MHolt__Content__c = msg, MHolt__From_User__c = sdr, MHolt__To_User__c = recip, MHolt__From_Name__c = nm, MHolt__Message_Id__c = id);
        String errors = '';
        Database.SaveResult result = EventBus.publish(evt);
        if (!result.isSuccess()) {
            for(Database.Error err : result.getErrors()) {
                errors += err.getStatusCode() + ' - ' + err.getMessage();
            }     
        }
        return errors;
    }

    /*
        setChatRead
        Set the latest messages between the running user and the user passed to the method as "read"
        Only apply to the latest 50 messages
    */
    @AuraEnabled
    public static String setChatRead(String userId){
        String thisUserLike = '%' + Userinfo.getUserId() + '%';
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT Id, OwnerId, MHolt__Read__c, createdDate 
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Read__c = false 
                                                AND OwnerId =: userId
                                                AND MHolt__Participants__c Like: thisUserLike
                                                ORDER BY createdDate DESC
                                                Limit 50];
        for(MHolt__Chat_Message__c cm : chatMsgs){
            cm.MHolt__Read__c = true;
        }
        try{
            update chatMsgs;
            return 'Success';
        }catch(Exception e){
            return e.getMessage();
        }
    }

    /*
        postToChatter
        Take the inbound messages and post them to chatter as the user's who wrote them. This requires the permission set to be applied to
        users, else the submission will fail. Strip out all instances of <br> and <strike> as these cause errors posting to Chatter
    */
    @AuraEnabled
    public static String postToChatter(List<String> chatIds, String recordId){
        Blob cryptoKey = getCryptoKey();
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT Id, name, OwnerId, Owner.Name, MHolt__From_Name__c, MHolt__Message__c, MHolt__Participants__c, createdDate
                                                FROM MHolt__Chat_Message__c 
                                                WHERE Id in : chatIds
                                                ORDER BY createdDate ASC];
        
        if(chatMsgs.size() > 0){
            try{
                String decryptedMsg = doDecryption(chatMsgs[0].MHolt__Message__c, cryptoKey);
                FeedItem firstPost = new FeedItem(createdById = chatMsgs[0].OwnerId, body = decryptedMsg, isRichText = true, parentId = recordId);
                insert firstPost;
                chatMsgs.remove(0);
                List<FeedComment> comments = new List<FeedComment>();
                for(MHolt__Chat_Message__c msg: chatMsgs){
                    decryptedMsg = doDecryption(msg.MHolt__Message__c, cryptoKey);
                    decryptedMsg = stripCommentForChatter(decryptedMsg);
                    FeedComment fc = new FeedComment(createdById = msg.OwnerId, CommentBody = decryptedMsg, isRichText = true, FeedItemId = firstPost.Id);
                    comments.add(fc);
                }
                insert comments;
            }catch (exception e){
                return e.getMessage();
            }
        }
        
        return 'Messages Successfully posted to Chatter!';
    }

    /*
        stripCommentForChatter
        Some HTML tags throw errors when they're posted in Chatter, here we strip them out
    */
    public static String stripCommentForChatter(String str){
        str = str.replaceAll('<br>', '');
        str = str.replaceAll('<strike>', '');
        str = str.replaceAll('</strike>', '');
        return str;
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
                    userTime = userTime.addHours(Integer.valueOf(denominationOffsets[0]));
                    userTime = userTime.addMinutes(Integer.valueOf(denominationOffsets[1]));
                    userTimes.put(u.id, userTime);
                }
            }
        }
        
        return userTimes;
    }

    /*
        getChatHistory
        Called when the component loads, or when the user requests a greater number of chat messages
        Takes the ID of both users as Strings and the number of messages to be retrieved
        Handles getting a batch of historic messages out of the database, depending on value of lim
        Decrypts each message and returns the messages to component as MessageWrappers in order to render them on screen
    */
    @AuraEnabled
    public static List<MessageWrapper> getChatHistory(String user1, String user2, Integer lim){
        List<MessageWrapper> returnMessages = new List<MessageWrapper>();
        Blob cryptoKey = getCryptoKey();
        String user1Like = '%' + user1 + '%';
        String user2Like = '%' + user2 + '%';
        //If either of the users are groups, we need to get every message in that group, not just the messages with this user. 
        //Replace both WHERE parameters with the ID of the group
        if(user1Like.startsWith('%0F9')){
            user2Like = user1Like;
        }else if(user2Like.startsWith('%0F9')){
            user1Like = user2Like;
        }
        //Need to order DESC to get the latest messages, as we pull a maximum of lim number. Sort ASC will bring back the very oldest messages and miss the most recent
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT Id, name, OwnerId, Owner.Name, MHolt__From_Name__c, MHolt__Message__c, MHolt__Participants__c, createdDate
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Participants__c like :user1Like
                                                AND MHolt__Participants__c like :user2Like
                                                ORDER BY createdDate DESC
                                                Limit :lim];
        List<User> users = getUsersWithSidkey(new List<String>{user1, user2});
        //Loop over the list of messages backwards, to sort their order, as they had to be pulled out of the DB DESC
        for(Integer i = chatMsgs.size() - 1; i >= 0; i--){
            MHolt__Chat_Message__c msg = chatMsgs[i];
            String decryptedMsg = doDecryption(msg.MHolt__Message__c, cryptoKey);

            Map<Id, DateTime> timesByUser = getTimeInTimezoneForUsers(users, msg.createdDate);
            MessageWrapper wrap = new MessageWrapper(decryptedMsg, msg.OwnerId, msg.Owner.Name, getTimeStamps(new List<DateTime>{timesByUser.get(userinfo.getuserid())})[0], msg.Id);
            returnMessages.add(wrap);
        }
        
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

    /*
        decryptMessage
        Called when a message arrives as a platform event on the chatWindow component
        Calls method to do the decryption of the message
        Calls method to get the correct time zone for the user
        Calls method to get the timestamp in the time zone of this particular user
        Returns MessageWrapper back with the decrypted message and timezone of the user, to be displayer on screen
    */
    @AuraEnabled
    public static MessageWrapper decryptMessage(String msg, String snd){
        String nm = '';
        try{
            User sender = [SELECT Id, Name FROM User WHERE id =: snd][0];
            nm = sender.Name;
        }catch(ListException e){
            //No sender param
        }
        String decryptedMsg = doDecryption(msg, getCryptoKey());
        List<User> currentUser = getUsersWithSidkey(new List<String>{userInfo.getUserId()});
        Map<Id, DateTime> timesByUser = getTimeInTimezoneForUsers(currentUser, system.now());
        MessageWrapper wrap = new MessageWrapper(decryptedMsg, getTimeStamps(new List<DateTime>{timesByUser.get(userInfo.getUserId())})[0]);

        return wrap;
    }

    /*
        getCryptoKey
        Gets the crypto key specific to this org, out of the DB. 
        Crypto key inserted as part of install script in EncryptionKeyGenerator Class
    */
    public static Blob getCryptoKey(){
        if(test.isrunningtest()){
            String keyAsString = '71Hnt5gqRX0N5CWUMWbBwozy5H8mSzXNtPArOJUhSao=';
            return EncodingUtil.base64decode(keyAsString);
        }else{
            MHolt__Chat_Message_Code__mdt cryptoKeyMetadata = [SELECT id, MHolt__Key__c FROM MHolt__Chat_Message_Code__mdt WHERE MasterLabel='Key'][0];
            return EncodingUtil.base64decode(cryptoKeyMetadata.MHolt__Key__c);
        }
    }

    /*
        doDecryption
        Decrypts messages using the crypto key specific to this org.
    */
    public static String doDecryption(String encryptedData, Blob cryptoKey){
        Blob base64EncryptedMessage = EncodingUtil.base64decode(encryptedData);
        Blob decryptedData = Crypto.decryptWithManagedIV('AES256', cryptoKey, base64EncryptedMessage);
        return decryptedData.toString();
    }

    /*
        MessageWrapper
        Holds the data structure used when showing a particular text box in the ChatWindow component
    */
    public class MessageWrapper{
        @AuraEnabled
        public String message;
        @AuraEnabled
        public String senderId;
        @AuraEnabled
        public String senderName;
        @AuraEnabled
        public String messageId;
        @AuraEnabled
        public String timestamp;

        public MessageWrapper(String m, String i, String n, String t, String mi){
            message = m;
            timestamp = t;
            senderId = i;
            senderName = n;
            messageId = mi;
        }

        public MessageWrapper(String m, String t){
            message = m;
            timestamp = t;
        }

    }
}