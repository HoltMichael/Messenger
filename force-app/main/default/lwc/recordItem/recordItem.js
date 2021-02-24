import { LightningElement, api, wire, track } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';


export default class RecordList extends LightningElement {
    @api record;
    @api fieldname;
    @api objectName;
    @track iconName;


    /*
        handleSelect
        Fire event to parent component noting which record has 
        been selected from this custom lookup component
    */
    handleSelect(event){
        event.preventDefault();
        const selectedRecord = new CustomEvent(
            "select",
            {
                detail : {record : () => this.record.Id, icon: () => this.iconName}
            }
        );
        this.dispatchEvent(selectedRecord);
    }

    get visibleField(){
        return this.record[this.fieldname];
    }

    @wire(getObjectInfo, { objectApiName:  '$objectName'})
    handleResult({error, data}) {
        if(data) {
            // access theme info here
            // icon URL is availe as themeInfo.iconUrl
            var url = data.themeInfo.iconUrl || {};
            var startInt = url.lastIndexOf("/") + 1;
            var stopInt = url.lastIndexOf("_");

            var prefixURL = url.substring(0, startInt -1);
            var prefixStartInt = prefixURL.lastIndexOf("/") +1;
            var prefix = prefixURL.substring(prefixStartInt);

            this.iconName = prefix + ':' + url.substring(startInt, stopInt);
        }
        if(error) {
            console.log('erroring');
            // handle error
        }
    }
}