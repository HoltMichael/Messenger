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
        searchKey = String.escapeSingleQuotes(searchKey);
        String key = '%' + searchKey + '%';
        system.debug([SELECT Id, Name FROM Group WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50]);
        return [SELECT Id, Name FROM Group WHERE Name LIKE :key WITH SECURITY_ENFORCED LIMIT 50];
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
