import { LightningElement, api } from 'lwc';

export default class LoadFullHistoryModal extends LightningElement {
    @api recipientName;
    handleConfirmation(event){
        const confirmEvent = new CustomEvent('confirm', {
            detail: { numRecs: event.currentTarget.dataset.number }
        });
        this.dispatchEvent(confirmEvent);
    }

    handleClose(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}