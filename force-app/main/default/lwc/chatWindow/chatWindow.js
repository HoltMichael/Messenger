import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import getTimeStampForRecipient from '@salesforce/apex/SendMessageHandler.getTimeStampForRecipient';
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
                this.displayMessage(result);
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
            });
    }

    //History messages are missing the sender name!
    displayMessage(allMessageContents){
        console.log('Displaying the following message: ' + allMessageContents);
        allMessageContents.forEach(msg => {
            console.log(msg);
            var cls = '';
            console.log(msg.senderId);
            if(msg.senderId == this.userId){
                cls = 'my-message both-message slds-float_right';
            }else{
                console.log('left');
                cls = 'their-message both-message slds-float_left';
            }
            this.chatText.push({text: msg.message, senderName: msg.senderName, timestamp: msg.timestamp, class: cls});
            //Scroll to the bottom of the div, waiting for the div to actually contain the chat first
            this.delayTimeout = setTimeout(() => {
                this.scrollToBottom();
            }, 100);
        });
        this.scrollToBottom;
    }

    //Scroll to the bottom of the chat window.
    scrollToBottom(){
        var objDiv = this.template.querySelector('.slds-scrollable');
        objDiv.scrollTop = objDiv.scrollHeight;
    }

    @api
    decryptMessage(message, sender, recip, msgTime) {
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                if(this.userId == sender){
                    console.log('This is the sender');
                    var fullMessage = [{message: result, senderId: sender, timestamp: msgTime}];
                    console.log('This is the message: ' + fullMessage);
                    this.displayMessage(fullMessage);
                }else{    
                    this.getTimeStampForRecipient(msgTime, sender, result);
                }
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

    @api
    getTimeStampForRecipient(time, sender, msg) {
        getTimeStampForRecipient({tm: time})
            .then(result => {
                console.log('This is the receiver');
                //this.chatText.push (result + ' ' + msg);
                var fullMessage = [{message: msg, senderId: sender, timestamp: result}];
                console.log('This is the message: ' + fullMessage);
                this.displayMessage(fullMessage);
            })
            .catch(error => {
                this.error = error;
            })
    }

    showToast(msg) {
        var strippedMsg = msg.replace(/(<([^>]+)>)/ig,"");
        const event = new ShowToastEvent({
            title: this.recipientName,
            message: strippedMsg,
        });
        this.dispatchEvent(event);
    }

    sendMessage(message) {       
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

        /*@track threadList = [{Id:'001',Name:'Thread 1'},
        {
            Id:'002',
            Name:'Thread 2'
        }
    ];*/
}