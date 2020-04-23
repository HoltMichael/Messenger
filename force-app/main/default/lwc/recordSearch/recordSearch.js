import { LightningElement, wire, track, api} from 'lwc';

export default class recordSearch extends LightningElement {
    @api objectNotSelected;
    @track disabled = false;
    @track required = false;
    @track searchKey;
    
    handleChange(event){
        const searchKey = event.target.value;
        /* eslint-disable no-console */
        event.preventDefault();
        const searchEvent = new CustomEvent(
            'change', 
            { 
                detail : searchKey
            }
        );
        this.dispatchEvent(searchEvent);
    }
}