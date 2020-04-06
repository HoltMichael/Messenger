import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import Id from '@salesforce/user/Id'; 

export default class Messenger extends LightningElement {
    selectedChatId;
    selectedChatName;
    @track chatWindows = [];
    @track objUser = {};
    userId = Id;
    @track channelName = '/event/MHolt__Message__e';
    @track isSubscribeDisabled = false;
    @track isUnsubscribeDisabled = !this.isSubscribeDisabled;
    latestMessage;

    //Move the focus into the newly created window
    //If the message is incoming, immediately move the focus out (Don't want to jump tab without the user's action)
    //This prevents the tab from lazy loading and causing future messages to be missed
    constructor() {
        super();   
        this.addEventListener('windowChange', this.handleWindowChange.bind(this));
    }
    handleWindowChange(event) {
        this.callFuncAfterTimer(this.setActiveTab, this.selectedChatId, 10);
        if(!event.detail.focus()){
            this.callFuncAfterTimer(this.setActiveTab,'Home', 10);
            //We need to re-send the message to the child, once it's been created. Since it didn't exist before. 
            //Make sure this is also delayed, since it needs to land after all historical messages are pulled out of the DB.
            this.callFuncAfterTimer(this.passMessagetoChild, null, 500);
        }
    }

    //Subscribe to the Platform Event as soon as the component renders
    connectedCallback(){
        this.handleSubscribe();
    }

    // Handles subscribe to PE
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        console.log('Received..');
        const messageCallback = (response) => {
            console.log('message received..');
            var windowOpen = false;
            this.latestMessage = {
                msg: response.data.payload.MHolt__Content__c,
                sender: response.data.payload.MHolt__From_User__c,
                recip: response.data.payload.MHolt__To_User__c,
                fromName: response.data.payload.MHolt__From_Name__c,
                msgTime1: response.data.payload.MHolt__Timestamp__c,
                msgTime2: response.data.payload.MHolt__Timestamp2__c
            }
            console.log('timestamps:');
            console.log(this.latestMessage.msgTime1);
            console.log(this.latestMessage.msgTime2);
            
            const allChats = this.template.querySelectorAll('c-chat-window');      
            
            allChats.forEach(thisChat => {
                if(thisChat.recipientId == this.latestMessage.sender || (this.latestMessage.sender == this.userId && this.latestMessage.recip == thisChat.recipientId)){
                    windowOpen = true;
                }
            });      

            if(!windowOpen){
                this.selectedChatId = this.latestMessage.sender;
                this.selectedChatName = this.latestMessage.fromName;
                this.createChatWindow(false);
            }  
            
            console.log('Passing message..');
            this.passMessagetoChild(this);
            //this.callFuncAfterTimer(this.passMessagetoChild(), null, 1000);
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback).then(response => {
            // Response contains the subscription information on successful subscribe call
            console.log('Successfully subscribed to : ', JSON.stringify(response.channel));
            this.subscription = response;
        });
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            // Error contains the server-side error
        });
    }

    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            console.log('Received error from server: ', JSON.stringify(error));
            // Error contains the server-side error
        });
    }
    
    // using wire service getting current user data
    @wire(getRecord, { recordId: Id, fields: ['User.FirstName', 'User.LastName', 'User.Name', 'User.Alias', 'User.IsActive'] })
    userData({error, data}) {
        if(data) {
            let objCurrentData = data.fields;

            this.objUser = {
                FirstName : objCurrentData.FirstName.value,
                LastName : objCurrentData.LastName.value,
                Name : objCurrentData.Name.value,
                Alias : objCurrentData.Alias.value,
                IsActive : objCurrentData.IsActive.value,
            }
        } 
        else if(error) {
            window.console.log('error ====> '+JSON.stringify(error))
        } 
    }

    //Set the properties on this component to the selected chat window
    handleSelect(event) {
        this.selectedChatId = event.detail.userId();
        this.selectedChatName = event.detail.userName();
        console.log('Opening window with this user ID: ' + this.selectedChatId);
        this.createChatWindow(true);
    }

    //Create a new chat window in the chat window array
    //Publish an event to get picked up by this component, in order to move the focus into the window
    createChatWindow(focusWindow){
        var chatWindow = {recipientId: this.selectedChatId, recipientName: this.selectedChatName};
        this.chatWindows.push({key: this.selectedChatId, value: this.selectedChatName});
        
        const selectEvent = new CustomEvent('windowChange', {
            detail: {focus: () => focusWindow ,bubbles: true}
        });
        this.dispatchEvent(selectEvent);

    }

    callFuncAfterTimer(func, param, delay) {
        this.delayTimeout = setTimeout(() => {
            func(this, param);
        }, delay);
    }

    passMessagetoChild(self){
        var allChats = self.template.querySelectorAll('c-chat-window');    
        allChats.forEach(thisChat => {
            if(thisChat.recipientId == self.latestMessage.sender || (self.latestMessage.sender == self.userId && self.latestMessage.recip == thisChat.recipientId)){
                thisChat.decryptMessage(self.latestMessage.msg, self.latestMessage.sender, self.latestMessage.recip, self.latestMessage.msgTime1, self.latestMessage.msgTime2);
            }
        });
    }

    setActiveTab(self, tabId){
        self.template.querySelector('lightning-tabset').activeTabValue = tabId;
    }
}