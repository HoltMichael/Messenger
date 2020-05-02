/*
    MessengerUtils
    Author: Michael Holt
    Date: 25th April 2020

    Backend code for the features on the Home tab within the Messenger component.
    Searches for Users and Groups visible to this particular user, up to a maximum of 50
*/

public with sharing class MessengerUtils {

    /*
        findUsers
        Used on the home screen to filter the search for individual user chats
        Returns a list of users who are active, have the Messenger permission set
        and whose name match the searchKey parameter. If the searchKey is empty, 
        all users matching the remaining criteria are returned
    */
    @AuraEnabled(cacheable=true)
    public static List<User> findUsers(String searchKey) {
        searchKey = String.escapeSingleQuotes(searchKey);
        String key = '%' + searchKey + '%';
        id i = userInfo.getUserId();
        List<Id> assIds = new List<Id>();
        List<PermissionSetAssignment> assignments = [SELECT AssigneeId FROM PermissionSetAssignment WHERE PermissionSet.Name = 'Messenger_User' AND PermissionSet.NamespacePrefix='MHOLT'];
        System.debug(assignments);
        for(PermissionSetAssignment ass : assignments){
            assIds.add(ass.AssigneeId);
        }
        return [SELECT Id, Name, Title, FullPhotoUrl FROM User WHERE Name LIKE :key AND Id !=: i AND isActive=True AND Id IN: assIds WITH SECURITY_ENFORCED LIMIT 50];
    }

    /*
        findGroups
        Used on the home screen to filter the search for group chats
        Populated the groups array in the Messenger component to ensure messages sent to a group
        are correctly triaged to the right users
    */
    @AuraEnabled(cacheable=true)
    public static List<CollaborationGroup> findGroups(String searchKey){
        searchKey = String.escapeSingleQuotes(searchKey);
        String key = '%' + searchKey + '%';
        id i = userInfo.getUserId();
        
        List<Id> groupIds = new List<Id>();
        List<CollaborationGroupMember> member = [SELECT CollaborationGroupId FROM CollaborationGroupMember WHERE MemberId=: i];
        for(CollaborationGroupMember m : member){
            groupIds.add(m.CollaborationGroupId);
        }
        return [SELECT Id, Name, SmallPhotoUrl FROM CollaborationGroup 
                                WHERE Id IN: groupIds
                                AND isArchived=false
                                AND Name Like: key];
    }

    /*
        getOfflineMessages
        Find all messages for this particular user, which have not yet been read (ie. User was offline)
        This allows the message windows to be popped open automatically, when the user comes online, to see messages they missed
        Returns the names of the people who sent the messages, mapped to their IDs
    */
    @AuraEnabled(cacheable=true)
    public static Map<Id,String> getOfflineMessages(){
        String userId = '%'+UserInfo.getUserId()+'%';
        Map<Id, String> userById = new Map<Id, String>();
        List<MHolt__Chat_Message__c> chatMsgs = [SELECT Id, OwnerId, Owner.Name, MHolt__Read__c,MHolt__Participant_1__c,MHolt__Participant_2__c,  createdDate 
                                                FROM MHolt__Chat_Message__c 
                                                WHERE MHolt__Read__c = false 
                                                AND OwnerId !=: userId
                                                AND MHolt__Participants__c Like: userId
                                                ORDER BY createdDate DESC];
        for(MHolt__Chat_Message__c msg : chatMsgs){
            If(!msg.MHolt__Participant_1__c.startsWith('0F9') && !msg.MHolt__Participant_2__c.startsWith('0F9')){
                userById.put(msg.OwnerId, msg.Owner.Name);
            }
        }
        return userById;
                                                
    }

    /*
        hasUserAccess
        Call the hasAccess method specifically for the User object and required fields
    */
    @AuraEnabled(cacheable=true)
    public static boolean hasUserAndEventAccess(){
        String obj = 'User';
        List<String> userFields = new List<String>{'Title','Name','Username','FullPhotoUrl'};
        List<String> eventFields = new List<String>{'MHolt__Content__c','MHolt__From_Name__c','MHolt__From_User__c','MHolt__Message_Id__c','MHolt__To_User__c'};
        boolean eventAccess = hasAccess('MHolt__Message__e', eventFields);
        boolean userAccess = hasAccess(obj,userFields);
        return userAccess && eventAccess; 
         
    }

    /*
        hasAccess
        Determines whether a given list of strings are accessible to the current user, for a given object
    */
    public static boolean hasAccess(String SObj, List<String> fields){
        SObjectType objType = Schema.getGlobalDescribe().get(SObj);
        Map<String,Schema.SObjectField> fieldMap = objType.getDescribe().fields.getMap();

        boolean access = true;
        for(String field : fields){
            try{
                if (!fieldMap.get(field).getDescribe().isAccessible()) {
                    access = false;
                }
            }catch(Exception e){
                //Field doesn't exist
                access = false;   
            }
        }
        return access;
    }
}
