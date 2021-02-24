import { LightningElement, track, api } from 'lwc';
import findRecords from '@salesforce/apex/recordSearchUtils.findRecords';
import getAllObjects from '@salesforce/apex/recordSearchUtils.getAllObjects';
export default class recordLookup extends LightningElement {
    @track records;
    @track error;
    @track selectedRecord;
    @track objects = [];
    @track value;
    @track loaded = false;
    @track objectNotSelected = true;
    @track confirmed = false;
    @track selectedRecordName = '';
    @track selectedRecordIcon = '';
    @api index;
    @api objectName;
    @api searchField = 'Name';
    displayField = 'Name';



    /*
        connectedCallback
        Call functions to initialise component
    */
    connectedCallback(){
        this.getAllObjects();
    }

    /*
        getAllObjects
        Retrieve all objects which the user has access to, that also have
        Chatter Feed enabled and have a 'Name' field. 
        (Version 1, only objects with a 'Name' field are supported for Chatter)
    */
    getAllObjects(){
        getAllObjects()
            .then(result => {
                this.objects = result;
                this.loaded = true;
            })
    }

    /*
        handleObjectSelect
        Handle the selection of a particular object from the object lookup,
        in order for it to be used in the record search
    */
    handleObjectSelect(event){
        this.objectName=event.detail.value;
        this.objectNotSelected = false;
        if(this.objectName == 'Case'){
            this.searchField = 'CaseNumber, Subject';
            this.displayField = 'CaseNumber';
        }else{
            this.searchField = 'Name';
            this.displayField = 'Name';
        }
        this.searchKey = '';
        this.records = [];
    }

    /*
        handlePopup
        Show the pop up window to show a confirmation message to the user.
        Popup message shows all selected Chat Messages in ChatWindow component
        and asks user to confirm they wish to post their message publicly
    */
    handlePopup(){
        this.dispatchEvent(new CustomEvent('popup'));
    }

    /*
        handleOnchange  
        Receives an event from the change in text in the recordSearch component
        Calls Apex to find a list of records matching the search criteria, the 
        object name and the search field
        Search field is always 'Name' in version 1
    */
    handleOnchange(event){
        const searchKey = event.detail.value;
        if(searchKey && searchKey != ''){
            /* Call the Salesforce Apex class method to find the Records */
            findRecords({
                searchKey : searchKey, 
                objectName : this.objectName, 
                searchField : this.searchField
            })
            .then(result => {
                this.records = result;
                for(let i=0; i < this.records.length; i++){
                    const rec = this.records[i];
                }
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.records = undefined;
            });
        }else{
            this.records = [];
        }
    }

    /*
        handleSelect
        Handle the selection of a particular record. Fire an event, captured by the ChatWindow component
        In order to eventually send messages to the Chatter feed related to this particular object
    */
    handleSelect(event){
        console.log('1');
        console.log(event);
        console.log(event.detail);
        console.log(event.detail.record());
        const selectedRecordId = event.detail.record();
        console.log('2');
        this.selectedRecord = this.records.find( record => record.Id === selectedRecordId);
        console.log('3');
        this.selectedRecordName = this.selectedRecord[this.displayField];
        console.log('4');
        this.selectedRecordIcon = event.detail.icon();
        console.log('5');
        console.log(event);
        console.log(event.icon);
        console.log(this.selectedRecordIcon);
        /* fire the event with the value of RecordId for the Selected RecordId */
        const selectedRecordEvent = new CustomEvent(
            "selectedrec",
            {
                detail : { recordId : selectedRecordId, index : this.index}
            }
        );
        this.dispatchEvent(selectedRecordEvent);
    }

    /*
        handleRemove
        Handles the logic for removing a particular record and therefore updating the UI
        back to a search bar. Fire event noting that the selectedRecord has been removed
    */
    handleRemove(event){
        event.preventDefault();
        this.selectedRecord = undefined;
        this.records = undefined;
        this.error = undefined;
        /* fire the event with the value of undefined for the Selected RecordId */
        const selectedRecordEvent = new CustomEvent(
            "selectedrec",
            {
                detail : { recordId : undefined, index : this.index}
            }
        );
        this.dispatchEvent(selectedRecordEvent);
    }


}