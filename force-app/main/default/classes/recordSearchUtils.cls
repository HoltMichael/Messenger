/*
    recordSearchUtils
    Author: Michael Holt
    Date: 25th April 2020

    Handles the backend processes for the recordLookup component. 
    When a user wishes to post messages to Chatter, we give them the option to post against specific records.
*/

public with sharing class recordSearchUtils {

    /*
        getAllObjects
        Gets all objects that this user has access to, which also have the Chatter Feed enabled and a name field exists on the object.
        For version 1, only object with a "Name" field can be searched. Improve this in later versions, so that all objects can be searched, using alternative fields
    */
    @AuraEnabled(cacheable=true)
    public static List<objectWrapper> getAllObjects(){
        List<objectWrapper> objs = new List<objectWrapper>();
        for (Schema.SObjectType obj : Schema.getGlobalDescribe().values() ){
            Schema.DescribeSObjectResult objResult = obj.getDescribe();
            if(objResult.isAccessible() && objResult.isFeedEnabled() && objResult.fields.getMap().containsKey('Name')){
                objs.add(new objectWrapper(objResult.getName(), objResult.getLabel()));
            }
        }
        return objs;
    } 
    
    /*
        findRecords
        Gets all records which match the search criteria provided in the search field, object picklist
    */
    @AuraEnabled(cacheable = true)
    public static List<SObject> findRecords(String searchKey, String objectName, String searchField){
        searchKey = String.escapeSingleQuotes(searchKey);
        objectName = String.escapeSingleQuotes(objectName);
        searchField = String.escapeSingleQuotes(searchField);
        String key = '%' + searchKey + '%';
        List<SObject> sObjectList = new List<SObject>();
        try{
            String query = 'Select Id, '+searchField+' From '+objectName +' Where '+searchField +' LIKE :key WITH SECURITY_ENFORCED LIMIT 10';
            sObjectList = Database.query(QUERY);
        }catch(System.QueryException e){
        }
        return sObjectList;
    }

    public class objectWrapper{
        @AuraEnabled
        public String value;
        @AuraEnabled
        public String label;
            
        public objectWrapper(String val, String lab){
            value = val;
            label = lab;
        }

    }
}
