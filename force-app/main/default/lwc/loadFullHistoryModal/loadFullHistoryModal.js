import { LightningElement, api } from 'lwc';

export default class LoadFullHistoryModal extends LightningElement {
    @api recipientName;
    
    /*
        handleConfirmation
        If the user wishes to load more records, fire an event to tell the ChatWindow
        component how many messages to render (300 / 50,000). Initially we load just
        the last 50 messages for performance reasons
    */
    handleConfirmation(event){
        const confirmEvent = new CustomEvent('confirm', {
            detail: { numRecs: event.currentTarget.dataset.number }
        });
        this.dispatchEvent(confirmEvent);
    }

    /*
        handleClose
        Tell the ChatWindow component to hide the modal
    */
    handleClose(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}