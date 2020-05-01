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
    */
    @AuraEnabled(cacheable=true)
    public static List<User> findUsers(String searchKey) {
        searchKey = String.escapeSingleQuotes(searchKey);
        String key = '%' + searchKey + '%';
        id i = userInfo.getUserId();
        return [SELECT Id, Name, Title, FullPhotoUrl FROM User WHERE Name LIKE :key AND Id !=: i AND isActive=True WITH SECURITY_ENFORCED LIMIT 50];
    }


    /*
        findGroups
        Used on the home screen to filter the search for group chats
    */
    @AuraEnabled(cacheable=true)
    public static List<Group> findGroups(String searchKey) {
        Id userId = UserInfo.getUserId();
        searchKey = String.escapeSingleQuotes(searchKey);
        String key = '%' + searchKey + '%';
                
        //Declaring a Set as we don't want Duplicate Group Ids 
        Set<Id> results = new Set<Id>(); 
        ///Declaring a Map for Group with Role 
        Map<Id,Id> grRoleMap = new Map<Id,Id>(); 
        //Populating the Map with RelatedID(i.e.UserRoledId) as Key 
        for(Group gr : [SELECT id, relatedid, name FROM Group]) { 
            grRoleMap.put(gr.relatedId,gr.id); 
        } 
        //Groups directly associated to user 
        Set<Id> groupwithUser = new Set<Id>(); 
        //Populating the Group with User with GroupId we are filtering only for Group of Type Regular,Role and RoleAndSubordinates 
        for(GroupMember u :[SELECT groupId 
                            FROM GroupMember 
                            WHERE UserOrGroupId=:userId 
                            AND (Group.Type = 'Regular' 
                            OR Group.Type='Role' 
                            OR Group.Type='RoleAndSubordinates')]) { 
            groupwithUser.add(u.groupId); 
        } 
        //Groups with Role 
        for(User u :[select UserRoleId from User where id=: userId]) { 
        //Checking if the current User Role is part of Map or not 
            if(grRoleMap.containsKey(u.UserRoleId)) { 
                results.add(grRoleMap.get(u.UserRoleId)); 
            } 
        } 
        //Combining both the Set 
        results.addAll(groupwithUser); 
        //Traversing the whole list of Groups to check any other nested Group 
        Map<Id,Id> grMap = new Map<Id,Id>(); 
        for(GroupMember gr : [SELECT id,UserOrGroupId,Groupid
                                FROM GroupMember where (Group.Type = 'Regular' 
                                OR Group.Type='Role' 
                                OR Group.Type='RoleAndSubordinates')]) { 
            grMap.put(gr.UserOrGroupId,gr.Groupid); 
        } 

        for(Id i :results) { 
            if(grMap.containsKey(i)) { 
                results.add(grMap.get(i)); 
            } 
        } 
        
        return [SELECT Id, Name FROM Group WHERE Id IN:results AND Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50];
    }




    /*
        getGroupsWithCurrentUser
        Provides a list of Group IDs that this user is a member of
        DELETE THIS, I SUSPECT
    */
    @AuraEnabled(cacheable=true)
    public static List<Id> getGroupsWithCurrentUser(){
        Id userId = UserInfo.getUserId();
        List<Id> groupIds = new List<Id>();
        List<GroupMember> gms = [SELECT GroupId FROM GroupMember WHERE UserOrGroupId =: userId];
        for(GroupMember gm : gms){
            groupIds.add(gm.id);
        }
        return groupIds;
    }

    /*
        getOfflineMessages
        Find all messages for this particular user, which have not yet been read (ie. User was offline)
        This allows the message windows to be popped open automatically, when the user comes online, to see messages they missed
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
            If(!msg.MHolt__Participant_1__c.startsWith('00G') && !msg.MHolt__Participant_2__c.startsWith('00G')){
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
