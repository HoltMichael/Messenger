import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import getTimeStamps from '@salesforce/apex/SendMessageHandler.getTimeStamps';
import getChatHistory from '@salesforce/apex/SendMessageHandler.getChatHistory';


export default class ChatWindow extends LightningElement {
    @api recipientName;
    @api recipientId;
    @api activeUsersName;
    @api userId;
    @track currentThread;
    @track chatText = [];
    response;
    @track mute = false;
    @track muteIcon = "utility:volume_off";

    connectedCallback(){
        console.log('recipientName: ' + this.recipientName);
        console.log('recipientId: ' + this.recipientId);
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
                this.chatText.push(result);
                this.error = undefined;
                //Scroll to the bottom of the div, waiting for the div to actually contain the chat first
                this.delayTimeout = setTimeout(() => {
                    this.scrollToBottom();
                }, 100);
            })
            .catch(error => {
                this.error = error;
            });
    }

    //Scroll to the bottom of the chat window.
    scrollToBottom(){
        var objDiv = this.template.querySelector('.slds-scrollable');
        objDiv.scrollTop = objDiv.scrollHeight;
    }

    @api
    decryptMessage(message, sender, recip, msgTime, msgTime2) {
        console.log('decrypting..');
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                console.log(msgTime);
                console.log(msgTime2);
                if(this.userId == sender){
                    this.chatText.push (msgTime + ' ' + result);
                }else{
                    this.chatText.push (msgTime2 + ' ' + result);
                }
                console.log('this.mute: ' + this.mute);
                console.log('sender ' + sender);
                console.log('this.userId ' + this.userId);
                if(!this.mute && sender != this.userId){
                    this.showToast(result);
                }
                this.error = undefined;
                this.scrollToBottom();
            })
            .catch(error => {
                this.error = error;
            });
    }

    showToast(msg) {
        console.log('toasting...');
        var strippedMsg = msg.replace(/(<([^>]+)>)/ig,"");
        const event = new ShowToastEvent({
            title: this.recipientName,
            message: strippedMsg,
        });
        this.dispatchEvent(event);
    }

    /*getTimeStamps(){
        getTimeStamps()
            .then(result => {
                return result;
            })
            .catch(error =>{
                console.log(error);
            });
    }*/

    sendMessage(message) {       
        console.log('Sending...');
        console.log(this.activeUsersName);
        console.log(this.userId);
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