import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import getTimeStamp from '@salesforce/apex/SendMessageHandler.getTimeStamp';
import getChatHistory from '@salesforce/apex/SendMessageHandler.getChatHistory';
import Id from '@salesforce/user/Id';

export default class ChatWindow extends LightningElement {
    @api recipientName;
    @api recipientId;
    @api activeUsersName;
    @api userId;
    //userId = Id;
    @track currentThread;
    @track chatText = '';
    response;
    @track mute = false;
    @track muteIcon = "utility:volume_off";

    connectedCallback(){
        console.log(this.userId);
        this.getChatHistory();
    }

    handleKeyPress(event){
        if(event.code === 'Enter'){
            this.sendMessage(event.target.value);
            this.template.querySelector("lightning-input-rich-text").value = '';
        }
    }

    getChatHistory() {
        
        getChatHistory({ user1: this.userId, user2: this.recipientId, days:7 })
            .then(result => {
                console.log(result);
                this.chatText += result;
                const blb    = new Blob(result, {type: "text/plain"});
                const reader = new FileReader();
                // Start reading the blob as text.
                reader.readAsText(blb);

                reader.addEventListener('loadend', (e) => {
                    const text = e.srcElement.result;
                    console.log(text);
                  });
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
            });
    }    



    @api
    decryptMessage(message, sender, recip, msgTime) {
        console.log('decrypting..');
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                this.chatText += msgTime + ' ' + result;
                if(!this.mute && sender != this.userId){
                    this.showToast(result);
                }
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
            });
    }

    showToast(msg) {
        var strippedMsg = msg.replace(/(<([^>]+)>)/ig,"");
        const event = new ShowToastEvent({
            title: this.recipientName,
            message: strippedMsg,
        });
        this.dispatchEvent(event);
    }

    getTimeStamp(){
        getTimeStamp()
            .then(result => {
                return result;
            })
            .catch(error =>{
                console.log(error);
            });
    }

    sendMessage(message) {       
        console.log(this.activeUsersName);
        sendMessage({ message: message, thread: this.currentThread, recipientId: this.recipientId, senderId: this.userId, name: this.activeUsersName })
            .then(result => {
                this.response = result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.contacts = undefined;
            });
    }

    toggleMute(){
        if(this.mute){
            this.mute = false;
            this.muteIcon = "utility:volume_off";
        }else{
            this.mute = true;
            this.muteIcon = "utility:alert";
        }
    }

    toggleFocus(event){
        this.template.querySelector('.focus-thread').classList.remove('focus-thread');
        event.currentTarget.classList.add('focus-thread');
        this.currentThread = event.currentTarget.id;
    }

        /*@track threadList = [
        {
            Id:'001',
            Name:'Thread 1'
        },
        {
            Id:'002',
            Name:'Thread 2'
        }
    ];*/
}