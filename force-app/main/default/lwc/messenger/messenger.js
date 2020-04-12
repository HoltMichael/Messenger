import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
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

    /*
        Move the focus into the newly created window
        If the message is incoming, immediately move the focus out (Don't want to jump tab without the user's action)
        This prevents the tab from lazy loading and causing future messages to be missed
    */
    constructor() {
        super();   
        this.addEventListener('windowChange', this.handleWindowChange.bind(this));
    }
    
    handleWindowChange(event) {
        console.log('called');
        this.callFuncAfterTimer(this.setActiveTab, this.selectedChatId, 10);
        if(!event.detail.focus()){
            this.callFuncAfterTimer(this.setActiveTab,'Home', 10);
            this.showFirstToast();
            //We need to re-send the message to the child, once it's been created. Since it didn't exist before. 
            //Make sure this is also delayed, since it needs to land after all historical messages are pulled out of the DB.
            //this.callFuncAfterTimer(this.passMessagetoChild, null, 500); //TODO: Delete this and provide a proper description for the function
        }
    }

    /*
        showFirstToast
        Show the toast for the first message inside a chat window. Not using the inner component toast function
        As calling this needs to be done after the component exists and needs to decrypt the message. Firing an
        informative toast here is quicker.
    */
    showFirstToast(){
        const event = new ShowToastEvent({
            title: this.selectedChatName,
            message: 'New Message!',
        });
        this.dispatchEvent(event);
    }

    //Subscribe to the Platform Event as soon as the component renders
    connectedCallback(){
        this.handleSubscribe();
    }

    /*
        handleWindowClose
        Handles the incoming event from the chatWindow component
        Identifies the position of the current window and removes it from the array, closing the tab
    */
    handleWindowClose(event){
        console.log(event.detail.recipientId);
        var indexOfWindow = this.getChatWindowIndex(event.detail.recipientId);
        this.chatWindows.splice(indexOfWindow, 1);
    }

    // Handles subscribe to PE
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        console.log('Received..');
        const messageCallback = (response) => {
            console.log('message received..');
            this.latestMessage = {
                msg: response.data.payload.MHolt__Content__c,
                sender: response.data.payload.MHolt__From_User__c,
                recip: response.data.payload.MHolt__To_User__c,
                fromName: response.data.payload.MHolt__From_Name__c
            }
            
            const allChats = this.template.querySelectorAll('c-chat-window');      
            //If the window isn't already open and it wasn't this user that sent the message, open a chat window for the inbound message sender
            if(this.getChatWindowIndex(this.latestMessage.sender) == -1 && this.latestMessage.sender != this.userId){
                this.selectedChatId = this.latestMessage.sender;
                this.selectedChatName = this.latestMessage.fromName;
                this.createChatWindow(false);
            }  
            this.passMessagetoChild(this);
        };

        // Invoke subscribe method of empApi. Pass reference to messageCallback
        subscribe(this.channelName, -1, messageCallback).then(response => {
            // Response contains the subscription information on successful subscribe call
            console.log('Successfully subscribed to : ', JSON.stringify(response.channel));
            this.subscription = response;
        });
    }

    getChatWindowIndex(windowId){
        var windowFilter = (element) => element.key == windowId;
        return this.chatWindows.findIndex(windowFilter);
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

    /*
        handleSelect
        Handle the select event from the userSearch component.
        Determine whether the selected chat window is already open. If it is, give it focus
        If the window is not open, set the relevant properties on this component and then create the window
    */
    handleSelect(event) {
        var indexOfWindow = this.getChatWindowIndex(event.detail.userId());
        if(indexOfWindow == -1){
            this.selectedChatId = event.detail.userId();
            this.selectedChatName = event.detail.userName();
            this.createChatWindow(true);
        }else{
            this.setActiveTab(this, event.detail.userId());
        }
    }

    //Create a new chat window in the chat window array
    //Publish an event to get picked up by this component, in order to move the focus into the window
    createChatWindow(focusWindow){
        //var chatWindow = {recipientId: this.selectedChatId, recipientName: this.selectedChatName};
        this.chatWindows.push({key: this.selectedChatId, value: this.selectedChatName});
        //if(focusWindow){
            const selectEvent = new CustomEvent('windowChange', {
                detail: {focus: () => focusWindow ,bubbles: true}
            });
            this.dispatchEvent(selectEvent);
        //}
    }

    callFuncAfterTimer(func, param, delay) {
        this.delayTimeout = setTimeout(() => {
            func(this, param);
        }, delay);
    }

    /*
        Find the correct chat window and ping the message off
    */
    passMessagetoChild(self){
        var allChats = self.template.querySelectorAll('c-chat-window');    
        allChats.forEach(thisChat => {
            if(thisChat.recipientId == self.latestMessage.sender || (self.latestMessage.sender == self.userId && self.latestMessage.recip == thisChat.recipientId)){
                thisChat.decryptMessage(self.latestMessage.msg, self.latestMessage.sender, self.latestMessage.fromName);
            }
        });
    }

    setActiveTab(self, tabId){
        self.template.querySelector('lightning-tabset').activeTabValue = tabId;
    }
}