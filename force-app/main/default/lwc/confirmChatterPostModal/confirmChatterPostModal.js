import { LightningElement,track, api } from 'lwc';

export default class ConfirmChatterPostModal extends LightningElement {
    @track header = 'Confirm Chatter Post';
    @track subtitle;
    @api messages = [];
    @api recipientName;

    /*
        connectedCallback
        Set the message of the modal to be shown to the user
    */
    connectedCallback(){
        this.subtitle = 'Are you sure you wish to post the following message to Chatter? This may allow other members of your organisation to see your chat. <b>Ensure you have the consent of '
        this.subtitle += '' + this.recipientName + ' before posting anything publicly. </b>';
    }

    /*
        handleSend
        Fire event to tell the parent component to post the messages to Chatter
    */
    handleSend(){
        this.dispatchEvent(new CustomEvent('send'));
    }

    /*
        handleClose
        Fire event to tell the parent component to close the modal and not post to Chatter
    */
    handleClose(){
        this.dispatchEvent(new CustomEvent('close'));
    }
}