import { LightningElement, api } from 'lwc';

export default class RecordList extends LightningElement {
    @api record;
    @api fieldname;
    @api iconname;

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
                detail : this.record.Id
            }
        );
        this.dispatchEvent(selectedRecord);
    }
}