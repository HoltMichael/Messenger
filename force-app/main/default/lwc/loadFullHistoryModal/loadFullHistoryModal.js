import { LightningElement, api } from 'lwc';

export default class LoadFullHistoryModal extends LightningElement {
    @api recipientName;
    handleConfirmation(){
        this.dispatchEvent(new CustomEvent('confirm'));
    }

    handleClose(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}