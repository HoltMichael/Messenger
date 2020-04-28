import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { subscribe, unsubscribe, onError, setDebugFlag, isEmpEnabled } from 'lightning/empApi';
import hasUserAndEventAccess from '@salesforce/apex/MessengerUtils.hasUserAndEventAccess';
import Id from '@salesforce/user/Id'; 

export default class Messenger extends LightningElement {
    //Populated with the ID of the latest user who the current user wishes to chat to
    selectedChatId;
    //Populated with the full name of the latest user who the current user wishes to chat to
    selectedChatName;
    //Photo is not used, introduce this for a future release
    selectedChatPhoto;
    userId = Id;
    //Used for storing info for the latest message that's come in
    latestMessage;
    //The platform event bus to subscribe to
    channelName = '/event/MHolt__Message__e';
    //Holds information for all of the currently open chat windows (tabs)
    @track chatWindows = [];
    @track objUser = {};
    @track access;
    @track loading=true;

    /*
        wiredAccess
        Check that the current user has access to the user object, to initiate a conversation with them
        Show a loading window whilst this check happens. If the user does have access, call function to
        subscribe to the platform event
    */
    @wire(hasUserAndEventAccess) 
    wiredAccess({error, data}){
        if(data === true){
            this.loading = false;
            this.access = data;
            this.handleSubscribe();
        }else if(data === false){
            this.loading = false;
            this.access = false;
        }else if(error){
            this.loading = true;
            this.access = false;
        }
    }


    /*
        Move the focus into the newly created window
        If the message is incoming, immediately move the focus out (Don't want to jump tab without the user's action)
        This prevents the tab from lazy loading and causing future messages to be missed
    */
    constructor() {
        super();   
        this.addEventListener('windowChange', this.handleWindowChange.bind(this));
    }
    
    /*
        handleWindowChange
        Change the focus of the user's view to the new tab. If the tab has opened as a result of a new 
        inbound message (window that wasn't previously open), then rapidly switch back to the previous tab.
        We need to initially jump into this tab, to ensure that it doesn't lazy load and make sure the future
        messages are caught here.
    */
    handleWindowChange(event) {
        this.callFuncAfterTimer(this.setActiveTab, this.selectedChatId, 10);
        if(!event.detail.focus()){
            this.callFuncAfterTimer(this.setActiveTab,'Home', 10);
            this.showFirstToast();
        }
    }

    /*
        showFirstToast
        Show the toast for the first message inside a chat window. Not using the inner component toast function
        As calling this needs to be done after the component exists and needs to decrypt the message. Firing a
        slightly less informative toast here for this first message is quicker. All future messages are handled
        by chatWindow's fireToast function
    */
    showFirstToast(){
        const event = new ShowToastEvent({
            title: this.selectedChatName,
            message: 'New Message!',
        });
        this.dispatchEvent(event);
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

    /*
        handleSubscribe
        Handles the subscription to the platform event and all inbound messages.
        Each message is set to the latestMessage var, to be used elsewhere in the component
        and eventually sent to the Child component in the passMessagetoChild function
    */
    handleSubscribe() {
        // Callback invoked whenever a new event message is received
        const messageCallback = (response) => {
            this.latestMessage = {
                msg: response.data.payload.MHolt__Content__c,
                sender: response.data.payload.MHolt__From_User__c,
                recip: response.data.payload.MHolt__To_User__c,
                fromName: response.data.payload.MHolt__From_Name__c,
                messageId: response.data.payload.MHolt__Message_Id__c
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

        //Do not subscribe to the platform event and consume allocations if we do not
        //have access to the object anyway
        if(this.access){
            // Invoke subscribe method of empApi. Pass reference to messageCallback
            subscribe(this.channelName, -1, messageCallback).then(response => {
                // Response contains the subscription information on successful subscribe call
                this.subscription = response;
            });
        }
    }

    /*
        getChatWindowIndex    
        Takes an ID of a chat Window/Tab (which is the Id of the user or group being chatted to)
        Returns the index at which the particular window sits within the chatWindows array
        Used for checking whether a chat window is already open, and for closing windows
        by removing them from this array
    */
    getChatWindowIndex(windowId){
        var windowFilter = (element) => element.key == windowId;
        return this.chatWindows.findIndex(windowFilter);
    }

    /*
        registerErrorListener
        Handle if something goes wrong in the platform event subscription.
        Calls method to show generic error.
    */
    registerErrorListener() {
        // Invoke onError empApi method
        onError(error => {
            this.showErrorToast;
            //console.log('Received error from server: ', JSON.stringify(error));
        });
    }

    /*
        showErrorToast
        Show generic message that something has gone wrong with the component.
        Used for when an error occurs with the platform event.
    */
    showErrorToast(){
        const event = new ShowToastEvent({
            title: 'Something Went Wrong!',
            message: 'Messenger has experienced an issue and may not work as intended',
            variant: 'error'
        });
        this.dispatchEvent(event);
    }

    
    
    /*
        userData
        Use the wire service to get current user information
    */
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
            this.selectedChatPhoto = event.detail.userPic();
            this.createChatWindow(true);
        }else{
            this.setActiveTab(this, event.detail.userId());
        }
    }


    /*
        createChatWindow
        Create a new element in the chat window array, which is rendered on screen as a tab
        Publish an event to get picked up by this component, in order to move the focus into the window
    */
    createChatWindow(focusWindow){
        this.chatWindows.push({key: this.selectedChatId, value: this.selectedChatName, photo: this.selectedChatPhoto});
        const selectEvent = new CustomEvent('windowChange', {
            detail: {focus: () => focusWindow ,bubbles: true}
        });
        this.dispatchEvent(selectEvent);
    }

    /*
        callFuncAfterTimer
        Takes a function, 1 parameter and a delay timer
        Calls the function, with the specified paramter, after the delay period
    */
    callFuncAfterTimer(func, param, delay) {
        this.delayTimeout = setTimeout(() => {
            func(this, param);
        }, delay);
    }

    /*
        passMessagetoChild    
        Find the correct chat window and call the method to decrypt the message and 
        render it on screen within the correct component.
    */
    passMessagetoChild(self){
        var allChats = self.template.querySelectorAll('c-chat-window');    
        allChats.forEach(thisChat => {
            if(thisChat.recipientId == self.latestMessage.sender || (self.latestMessage.sender == self.userId && self.latestMessage.recip == thisChat.recipientId)){
                thisChat.decryptMessage(self.latestMessage.msg, self.latestMessage.sender, self.latestMessage.fromName, self.latestMessage.messageId);
            }
        });
    }

    /*
        setActiveTab    
        Takes an object and sets a particular tab within that object to the tabId provided.
        Typically, first parameter will be this.
    */
    setActiveTab(self, tabId){
        self.template.querySelector('lightning-tabset').activeTabValue = tabId;
    }
}