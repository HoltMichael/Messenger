import { LightningElement, track, wire } from 'lwc';
import { getRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent'
import { subscribe, onError } from 'lightning/empApi';
import hasUserAndEventAccess from '@salesforce/apex/MessengerUtils.hasUserAndEventAccess';
import getOfflineMessages from '@salesforce/apex/MessengerUtils.getOfflineMessages';
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
    //Holds the IDs of all the groups this user is a part of, so that they receive messages when they come in
    groupIds;
    //Holds information for all of the currently open chat windows (tabs)
    @track chatWindows = [];
    @track objUser = {};
    @track access;
    @track loading=true;
    showFirstToastPopup;

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
            this.showToast('Something Went Wrong!',error.body.message, 'error');
        }
    }

    /*
        getOfflineMessages
        Retrieves any messages that may have come in when 
        the user was offline and opens those respective tabs
        Turns off the "New Message" popup when the user first gets a message, otherwise they could be 
        inundated with toast messages for every offline message they received
        Send one generic toast instead, if they have received messages whilst offline
    */
   @wire(getOfflineMessages) 
   getOfflineMessages({error, data}){
       if(data){
            var hasMessages = false;
            this.showFirstToastPopup = false;
            for(let key in data) {
                if (data.hasOwnProperty(key)) {
                    if(key != this.userId){
                        hasMessages = true;
                        this.selectedChatId=key;
                        this.selectedChatName=data[key];
                        this.createChatWindow(false);
                    }
                }
            }
            this.showFirstToastPopup = true;
            if(hasMessages == true){
                this.showToast('New Messages Received Offline', 'Check your open tabs for new messages while you were gone')
            }
       }else if(error){
            this.showToast('Something went wrong!', error.body.message);
       }
   }

    populateGroups(event){
        this.groupIds = event.detail.groups.data;
    }

    /*
        constructor
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
            if(!this.template.querySelector('lightning-tabset')){
                tabVal = 'Home';
            }else{
                var tabVal = this.template.querySelector('lightning-tabset').activeTabValue;
            }
            this.callFuncAfterTimer(this.setActiveTab,tabVal, 10);
            this.showToast(this.selectedChatName, 'New Message!', 'info');
        }
    }

    /*
        showToast
        Show the toast for the first message inside a chat window. Not using the inner component toast function
        As calling this needs to be done after the component exists and needs to decrypt the message. Firing a
        slightly less informative toast here for this first message is quicker. All future messages are handled
        by chatWindow's fireToast function
    */
    showToast(title, message, variant){
        if(this.showFirstToastPopup){
            const event = new ShowToastEvent({
                title: title,
                message: message,
                variant: variant
            });
            this.dispatchEvent(event);
        }
    }

    /*
        handleWindowClose
        Handles the incoming event from the chatWindow component
        Identifies the position of the current window and removes it from the array, closing the tab
    */
    handleWindowClose(event){
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
                messageId: response.data.payload.MHolt__Message_Id__c,
                isGroup: false
            }
            //If the window isn't already open and it wasn't this user that sent the message, open a chat window for the inbound message sender
            if(this.groupIds.indexOf(this.latestMessage.recip > -1) && this.latestMessage.recip.startsWith('0F9')){
                this.latestMessage.isGroup = true;
                this.selectedChatId =  this.latestMessage.recip;
                this.selectedChatName = this.groupIds.find(element => element.Id == this.latestMessage.recip).Name;
                if(this.getChatWindowIndex(this.latestMessage.recip) == -1){
                    this.createChatWindow(false);
                }   
            //}else if(this.getChatWindowIndex(this.latestMessage.sender) == -1 && this.latestMessage.sender != this.userId){
            }else if(this.getChatWindowIndex(this.latestMessage.sender) == -1 && this.latestMessage.sender != this.userId && this.latestMessage.recip == this.userId){
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
            this.showToast('Something Went Wrong!',error.body.message, 'error');
        });
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
            this.showToast('Something Went Wrong!',error.body.message, 'error');
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
            //this.selectedChatPhoto = event.detail.userPic();
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
        this.chatWindows.push({key: this.selectedChatId, value: this.selectedChatName});
        const windowEvent = new CustomEvent('windowChange', {
            detail: {focus: () => focusWindow ,bubbles: true}
        });
        this.dispatchEvent(windowEvent);
    }

    getChatHistory(recordLimit) {
        this.loading = true;
        getChatHistory({ user1: this.userId, user2: this.recipientId, lim: recordLimit})
            .then(result => {
                this.chatText = [];
                this.displayMessage(result); 
            })
            .catch(error => {
                this.showToast('Something Went Wrong!',error.body.message, 'error');
            });
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
            //If we're messaging a group
            if(this.latestMessage.isGroup && this.latestMessage.recip == thisChat.recipientId){
                thisChat.decryptMessage(self.latestMessage.msg, self.latestMessage.sender, self.latestMessage.fromName, self.latestMessage.messageId);
                this.break;
            //If we're messaging an individual
            }else if(!this.latestMessage.isGroup && (thisChat.recipientId == self.latestMessage.sender || (self.latestMessage.sender == self.userId && self.latestMessage.recip == thisChat.recipientId))){
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