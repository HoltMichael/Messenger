import { LightningElement, api, track } from 'lwc';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import sendMessage from '@salesforce/apex/SendMessageHandler.sendMessage';
import decryptMessage from '@salesforce/apex/SendMessageHandler.decryptMessage';
import Id from '@salesforce/user/Id';

export default class ChatWindow extends LightningElement {
    @track channelName = '/event/MHolt__Message__e';
    @track isSubscribeDisabled = false;
    @track isUnsubscribeDisabled = !this.isSubscribeDisabled;
    @api recipientName;
    @api recipientId;
    @api activeUsersName;
    userId = Id;
    @track currentThread;
    @track chatText = '';
    @track latestSender = '';
    @track name;
    currentThread;
    subscription = {};
    @track objUser = {};
    response;

    connectedCallback(){
        this.handleSubscribe();
    }

    // Tracks changes to channelName text field
    handleChannelName(event) {
        this.channelName = event.target.value;
    }

    // Handles subscribe button click
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        const messageCallback = (response) => {
            var msg = response.data.payload.MHolt__Content__c;
            var sender = response.data.payload.MHolt__From_User__c;
            var recip = response.data.payload.MHolt__To_User__c
            console.log('Message content: ' + (response.data.payload.MHolt__Content__c));
            console.log(recip);
            console.log(this.userId);
            if(recip == this.userId){
                this.decryptMessage(msg, sender);
            }
            // Response contains the payload of the new message received
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback).then(response => {
            // Response contains the subscription information on successful subscribe call
            console.log('Successfully subscribed to : ', JSON.stringify(response.channel));
            this.subscription = response;
            this.toggleSubscribeButton(true);
        });
    }

    // Handles unsubscribe button click
    handleUnsubscribe() {
        this.toggleSubscribeButton(false);

        // Invoke unsubscribe method of empApi
        unsubscribe(this.subscription, response => {
            console.log('unsubscribe() response: ', JSON.stringify(response));
            // Response is true for successful unsubscribe
        });
    }

    toggleSubscribeButton(enableSubscribe) {
        this.isSubscribeDisabled = enableSubscribe;
        this.isUnsubscribeDisabled = !enableSubscribe;
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            // Error contains the server-side error
        });
    }

    handleKeyPress(event){
        if(event.code === 'Enter'){
            this.sendMessage(event.target.value);
            this.template.querySelector("lightning-input-rich-text").value = '';
        }

    }

    decryptMessage(message, sender) {
        decryptMessage({ msg: message, snd: sender })
            .then(result => {
                this.chatText += result;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
            });
    }

    sendMessage(message) {
        sendMessage({ message: message, thread: this.currentThread, recipientId: this.recipientId, senderId: Id })
            .then(result => {
                this.chatText += this.activeUsersName +':'+ message;
                this.response = result;
                this.error = undefined;
                //console.log(this.response);
                //console.log(this.error);
            })
            .catch(error => {
                this.error = error;
                this.contacts = undefined;
                //console.log(this.error);
                //console.log(this.response);
            });
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