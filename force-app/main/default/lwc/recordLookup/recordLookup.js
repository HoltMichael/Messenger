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
    @api index;
    @api iconname = "standard:account";
    @api objectName;
    @api searchfield = 'Name';


    connectedCallback(){
        this.getAllObjects();
    }

    getAllObjects(){
        getAllObjects()
            .then(result => {
                this.objects = result;
                this.loaded = true;
            })
    }

    handleObjectSelect(event){
        this.objectName=event.detail.value;
    }

    handleOnchange(event){
        //event.preventDefault();
        const searchKey = event.detail.value;
        //this.records = null;
        /* eslint-disable no-console */
        //console.log(searchKey);

        /* Call the Salesforce Apex class method to find the Records */
        findRecords({
            searchKey : searchKey, 
            objectName : this.objectName, 
            searchField : this.searchfield
        })
        .then(result => {
            this.records = result;
            for(let i=0; i < this.records.length; i++){
                const rec = this.records[i];
                this.records[i].Name = rec[this.searchfield];
            }
            this.error = undefined;
            //console.log(' records ', this.records);
        })
        .catch(error => {
            this.error = error;
            this.records = undefined;
        });
    }
    handleSelect(event){
        const selectedRecordId = event.detail;
        /* eslint-disable no-console*/
        this.selectedRecord = this.records.find( record => record.Id === selectedRecordId);
        /* fire the event with the value of RecordId for the Selected RecordId */
        const selectedRecordEvent = new CustomEvent(
            "selectedrec",
            {
                //detail : selectedRecordId
                detail : { recordId : selectedRecordId, index : this.index}
            }
        );
        this.dispatchEvent(selectedRecordEvent);
    }

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